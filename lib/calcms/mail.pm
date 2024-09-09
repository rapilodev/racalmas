package mail;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Email::Sender::Simple();
use Email::Simple();
use Text::Unidecode qw(unidecode);

sub to_ascii {
    my ($s) = @_;
    my %translate = qw(
        Ä Ae
        ä ae
        Ö Oe
        ö oe
        Ü Ue
        ü ue
        ß ss
    );
    $s =~ s/([ÄäÖöÜüß])/$translate{$1}/g;
    $s = unidecode $s;
    return $s;
}

sub send($) {
    my ($mail) = @_;

    my $email = Email::Simple->create(
        header => [
            'Content-Type' => 'text/plain;',
            'From'     => $mail->{'From'},
            'To'       => $mail->{'To'},
            'Cc'       => $mail->{'Cc'},
            'Reply-To' => $mail->{'Reply-To'},
			'Subject' => to_ascii($mail->{'Subject'})
        ],
        body => to_ascii($mail->{'Data'})
    );
    Email::Sender::Simple->send($email);
}

# do not delete next line
return 1;
