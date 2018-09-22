#! /usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../calcms";

use Common ( 'info', 'error' );

use config();
use time();
use log();

$| = 1;

sub runJobs {
    my $jobs     = shift;
    my $startDir = shift;
    my $logDir   = shift;

    for my $job (@$jobs) {

        my $startFile = $startDir . '/' . $job->{name} . '.start.txt';
        my $startAge  = Common::getModifiedAt($startFile);
        next if $startAge == 0;

        my $logFile = $logDir . '/' . $job->{name} . '.log';
        my $logAge  = Common::getModifiedAt($logFile);
        next if $startAge < $logAge;

        # read parameters form start file
        my $content = log::load_file($startFile);

        #execute command
        my $command = $job->{command} . ' 2>&1 > ' . $logFile;
        my ( $exitCode, $result ) = Common::execute($command);
        error "exitCode=$exitCode on $command" if $exitCode != 0;
    }
}

sub check() {
    my $configFile = shift @ARGV;
    error qq{cannot read $configFile "$configFile"} unless -e $configFile;

    my $config = config::get($configFile);

    my $startDir = $config->{start_dir} || '';
    error 'missing configuration of jobs/start_dir!' if $startDir eq '';
    error "job dir does not exist '$startDir'"                              unless -e $startDir;
    error "cannot read from job dir '$startDir'. Please check permissions!" unless -w $startDir;

    my $logDir = $config->{log_dir} || '';
    error 'missing configuration of jobs/log_dir' if $logDir eq '';
    error "job log dir does not exist '$logDir'"                              unless -e $logDir;
    error "cannot read from job log dir '$logDir'. Please check permissions!" unless -r $logDir;
    error "cannot write to job log dir '$logDir'. Please check permissions!"  unless -w $logDir;

    my $jobs = $config->{job};
    error "no jobs defined!" if scalar @$jobs == 0;

    return ( $jobs, $startDir, $logDir );
}

sub main() {

    info "INIT\t" . time::time_to_datetime();
    Common::checkSingleInstance();
    my ( $jobs, $startDir, $logDir ) = check();

    #exit after a at most 10 minute timeout in case of hanging process
    local $SIG{ALRM} = sub { die "ERROR: exit due to synchronization hangs\n" };
    alarm 10 * 60;

    runJobs( $jobs, $startDir, $logDir );
    info "DONE\t" . time::time_to_datetime();
}

main();
