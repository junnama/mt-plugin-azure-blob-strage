package AzureBlobStrage::Callbacks;

use strict;
use MT::TheSchwartz;
use TheSchwartz::Job;
use Digest::MD5;
use MT::Serialize;

sub _put_data {
    my ( $cb, $fmgr, $from, $to, $type, $rv ) = @_;
    my $base_path = MT->config( 'AzureBlobSyncBasePath' );
    $base_path =~ s!/$!!;
    my $search_path = quotemeta( $base_path );
    if ( $to !~ /^$search_path/ ) {
        return;
    }
    my $data = { action => 'upload', path => $to };
    if ( MT->config( 'AzureRealtimeSync' ) ) {
        my $dirname = MT->config( 'AzureBlobDirName' ) || '';
        my $search_path = quotemeta( $base_path );
        my $blob = _blob();
        my $blob_path = $to;
        $blob_path =~ s/^$search_path//;
        my $res = $blob->upload( $dirname . $blob_path, $to );
        return;
    }
    my $ser = MT::Serialize->serialize( \$data );
    my $job = TheSchwartz::Job->new();
    $job->funcname( 'Deploy2Azure::Worker::Sync' );
    my $uniqkey = 'upload:' . Digest::MD5::md5_hex( $to );
    $job->uniqkey( $uniqkey );
    my $priority = 5;
    $job->priority( $priority );
    $job->coalesce( $uniqkey . ':' 
            . $$ . ':'
            . $priority . ':'
            . ( time - ( time % 10 ) ) );
    $job->arg( $ser );
    MT::TheSchwartz->insert( $job );
}

sub _delete {
    my ( $cb, $fmgr, $file ) = @_;
    my $base_path = MT->config( 'AzureBlobSyncBasePath' );
    $base_path =~ s!/$!!;
    my $search_path = quotemeta( $base_path );
    if ( $file !~ /^$search_path/ ) {
        return;
    }
    if ( MT->config( 'AzureRealtimeSync' ) ) {
        my $dirname = MT->config( 'AzureBlobDirName' ) || '';
        my $blob = _blob();
        my $blob_path = $file;
        $blob_path =~ s/^$search_path//;
        my $res = $blob->remove( $dirname . $blob_path );
        return;
    }
    my $data = { action => 'delete', path => $file };
    my $ser = MT::Serialize->serialize( \$data );
    my $job = TheSchwartz::Job->new();
    $job->funcname( 'Deploy2Azure::Worker::Sync' );
    my $uniqkey = 'delete:' . Digest::MD5::md5_hex( $file );
    $job->uniqkey( $uniqkey );
    my $priority = 4;
    $job->priority( $priority );
    $job->coalesce( $uniqkey . ':' 
            . $$ . ':'
            . $priority . ':'
            . ( time - ( time % 10 ) ) );
    $job->arg( $ser );
    MT::TheSchwartz->insert( $job );
}

sub _blob {
    require WindowsAzure::Blob;
    my $account_name = MT->config( 'AzureBlobAccountName' );
    my $primary_access_key = MT->config( 'AzureBlobPrimaryAccessKey' );
    my $container_name = MT->config( 'AzureBlobContainerName' );
    my $schema = MT->config( 'AzureBlobAPISchema' ) || 'https';
    my $blob = WindowsAzure::Blob->new( account_name => $account_name,
                                        primary_access_key => $primary_access_key,
                                        container_name => $container_name,
                                        schema => $schema );
    return $blob;
}

1;