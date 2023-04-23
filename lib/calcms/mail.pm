package mail;

use strict;
use warnings;
no warnings 'redefine';

use Email::Sender::Simple();
use Email::Simple();

sub send($) {
    my ($mail) = @_;

    my $email = Email::Simple->create(
        'Content-Type' => 'text/plain; charset=utf-8',
        header => [
            'From'     => $mail->{'From'},
            'To'       => $mail->{'To'},
            'Cc'       => $mail->{'Cc'},
            'Reply-To' => $mail->{'Reply-To'},
            'Subject'  => $mail->{'Subject'}
        ],
        body => $mail->{'Data'},
    );
    Email::Sender::Simple->send($email);
}

# do not delete next line
return 1;
