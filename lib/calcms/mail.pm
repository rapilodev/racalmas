package mail;

use strict;
use warnings;
no warnings 'redefine';

use Email::Sender::Simple();
use Email::Simple();
use MIME::Words qw(encode_mimeword);
use MIME::QuotedPrint qw(encode_qp);

sub send($) {
    my ($mail) = @_;

    my $email = Email::Simple->create(
        header => [
            'Content-Type' => 'text/plain;',
            'Content-Transfer-Encoding' => 'quoted-printable',
            'From'     => $mail->{'From'},
            'To'       => $mail->{'To'},
            'Cc'       => $mail->{'Cc'},
            'Reply-To' => $mail->{'Reply-To'},
            'Subject'  => encode_mimeword($mail->{'Subject'}, 'b', 'UTF-8')
        ],
        body => encode_qp($mail->{'Data'}),
    );
    Email::Sender::Simple->send($email);
}

# do not delete next line
return 1;
