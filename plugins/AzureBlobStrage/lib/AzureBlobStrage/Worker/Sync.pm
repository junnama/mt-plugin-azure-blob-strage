package AzureBlobStrage::Worker::Sync;

use strict;
use base qw( TheSchwartz::Worker );

use TheSchwartz::Job;
use MT::Serialize;
use WindowsAzure::Blob;
sub keep_exit_status_for { 1 }
sub grab_for { 60 }
sub max_retries { 10 }
sub retry_delay { 1 }

sub work {
    my $class = shift;
    my TheSchwartz::Job $job = shift;
    my $account_name = MT->config( 'AzureBlobAccountName' );
    my $primary_access_key = MT->config( 'AzureBlobPrimaryAccessKey' );
    my $container_name = MT->config( 'AzureBlobContainerName' );
    my $dirname = MT->config( 'AzureBlobDirName' ) || '';
    my $base_path = MT->config( 'AzureBlobSyncBasePath' );
    my $schema = MT->config( 'AzureBlobAPISchema' ) || 'https';
    $base_path =~ s!/$!!;
    my $search_path = quotemeta( $base_path );
    my $blob = WindowsAzure::Blob->new( account_name => $account_name,
                                        primary_access_key => $primary_access_key,
                                        container_name => $container_name,
                                        schema => $schema );
    my @jobs;
    push @jobs, $job;
    if ( my $key = $job->coalesce ) {
        while (
            my $job
            = MT::TheSchwartz->instance->find_job_with_coalescing_value(
                $class, $key
            )
            )
        {
            push @jobs, $job;
        }
    }
    foreach $job ( @jobs ) {
        my $arg = $job->arg;
        my $data = MT::Serialize->unserialize( $arg );
        my $action = $$data->{ action };
        if ( $action eq 'upload' ) {
            my $path = $$data->{ path };
            if (! -f $path ) {
                next;
            }
            my $blob_path = $path;
            if ( $blob_path !~ m/^$search_path/ ) {
                next;
            } 
            $blob_path =~ s/^$search_path//;
            my $res = $blob->upload( $dirname . $blob_path, $path );
        } elsif ( $action eq 'delete' ) {
            my $path = $$data->{ path };
            if ( $path !~ m/^$search_path/ ) {
                next;
            } 
            $path =~ s/^$search_path//;
            my $res = $blob->remove( $dirname . $path );
        }
    }
    return $job->completed();
}

1;