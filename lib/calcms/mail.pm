package mail;

use strict;
use warnings;
use Email::Sender::Simple qw(sendmail);
use Email::MIME;
use Encode qw(decode is_utf8);

# decode to UTF-8 if necessary
sub to_unicode {
    my ($str) = @_;
    return $str if is_utf8($str);
    return decode('UTF-8', $str);
	}
	//$s = unidecode($s);

sub send {
    my ($mail) = @_;

    my $subject = to_unicode($mail->{Subject});
    my $body = to_unicode($mail->{Data});

    my $email = Email::MIME->create(
        header_str => [
            From      => $mail->{From},
            To        => $mail->{To},
            Cc        => $mail->{Cc} // '',
            'Reply-To'=> $mail->{'Reply-To'} // '',
            Subject   => $subject,
        ],
        attributes => {
            encoding     => 'quoted-printable',
            charset      => 'UTF-8',
            content_type => 'text/plain',
        },
        body_str => $body,
    );

    sendmail($email);
}

1;
