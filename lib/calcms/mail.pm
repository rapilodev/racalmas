package mail;

use MIME::Lite();

sub send {
	my $mail = shift;

	my $msg = MIME::Lite->new(
		'From'     => $mail->{'From'},
		'To'       => $mail->{'To'},
		'Cc'       => $mail->{'Cc'},
		'Reply-To' => $mail->{'Reply-To'},
		'Subject'  => $mail->{'Subject'},
		'Data'     => $mail->{'Data'},
	);

	#print '<pre>';
	$msg->print( \*STDERR );

	#print '</pre>';

	$msg->send;
}

# do not delete next line
return 1;
