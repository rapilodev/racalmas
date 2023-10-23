package mail;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Email::Sender::Simple();
use Email::Simple();
use MIME::Words qw(encode_mimeword);
use Encode;

sub send($) {
    my ($mail) = @_;

    my $email = Email::Simple->create(
        'Content-Type' => 'text/plain; charset=utf-8',
        header => [
            'From'     => $mail->{'From'},
            'To'       => $mail->{'To'},
            'Cc'       => $mail->{'Cc'},
            'Reply-To' => $mail->{'Reply-To'},
            'Subject'  => encode_mimeword($mail->{'Subject'}, 'b', 'UTF-8')
        ],
        body => Encode::encode( utf8 => $mail->{'Data'} ),
    );
    Email::Sender::Simple->send($email);
}

# do not delete next line
return 1;
