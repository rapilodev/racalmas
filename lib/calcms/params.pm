package params; 
use warnings "all";
use strict;
use Data::Dumper;
use CGI;
use Apache2::Request;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get isJson);
our %EXPORT_TAGS = ( 'all'  => [ @EXPORT_OK ] );

sub debug;
my $isJson=0;

sub isJson{
    return $isJson;
}

sub get{
    #get the Apache2::RequestRec
	my $r=shift;

	my $tmp_dir      = '/var/tmp/';
	my $upload_limit = 1000*1024;

	my $cgi    = undef;
	my $status = undef;
	my $params = {};

    $isJson=0;

	if (defined $r){
		#print STDERR "Apache2::Request\n";
        #get Apache2::Request
		my $req = Apache2::Request->new($r, POST_MAX => $upload_limit, TEMP_DIR => $tmp_dir);

        for my $key ($req->param){
            $params->{scalar($key)}=scalar($req->param($key));
        }

		#copy params to hash
		#my $body=$req->body();
		#if (defined $body){
		#	for my $key (keys %$body){
		#		$params->{scalar($key)}=scalar($req->param($key));
		#	}
		#}
		$status = $req->parse; #parse
	}else{
		#print STDERR "CGI\n";
		$CGI::POST_MAX = $upload_limit;
		$CGI::TMPDIRECTORY=$tmp_dir;
		$cgi=new CGI();
		$status=$cgi->cgi_error()||$status;
		my %params=$cgi->Vars();
		$params=\%params;
	}
    $cgi=new CGI() unless(defined $cgi);

    $isJson=1 if (defined $params->{json}) && ($params->{json}eq'1');

    if(defined $status){
        $status='' if ($status eq 'Success');
        $status='' if ($status eq 'Missing input data');
        print $cgi->header.$status."\n" if($status ne'');
    }
    #print STDERR Dumper($params);
    #print $cgi->header.Dumper($params).$status;

	return ($cgi, $params, $status);
}

sub debug{
	my $message=shift;
	#print "$msg<br/>\n" if ($debug>0);
	#print "$message<br>\n";
	#log::print($message."\n") if ($debug);
}


#do not delete last line!
1;
