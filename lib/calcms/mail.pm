package mail;

use strict;
use warnings;
no warnings 'redefine';

use Email::Sender::Simple();
use Email::Simple();
use Text::Unidecode qw(unidecode);

sub to_ascii {
    my ($s) = @_;
    my %translate = (
    # a
    'á' => 'a', 'à' => 'a', 'â' => 'a', 'ä' => 'ae', 'ã' => 'a', 'å' => 'a', 'ā' => 'a',
    'ă' => 'a', 'ą' => 'a', 'æ' => 'ae',
    'Á' => 'A', 'À' => 'A', 'Â' => 'A', 'Ä' => 'Ae', 'Ã' => 'A', 'Å' => 'A', 'Ā' => 'A',
    'Ă' => 'A', 'Ą' => 'A', 'Æ' => 'AE',

    # e
    'é' => 'e', 'è' => 'e', 'ê' => 'e', 'ë' => 'e', 'ē' => 'e', 'ė' => 'e', 'ę' => 'e',
    'É' => 'E', 'È' => 'E', 'Ê' => 'E', 'Ë' => 'E', 'Ē' => 'E', 'Ė' => 'E', 'Ę' => 'E',

    # i
    'í' => 'i', 'ì' => 'i', 'î' => 'i', 'ï' => 'i', 'ī' => 'i', 'į' => 'i', 'ĩ' => 'i',
    'Í' => 'I', 'Ì' => 'I', 'Î' => 'I', 'Ï' => 'I', 'Ī' => 'I', 'Į' => 'I', 'Ĩ' => 'I',

    # o
    'ó' => 'o', 'ò' => 'o', 'ô' => 'o', 'ö' => 'oe', 'õ' => 'o', 'ø' => 'o', 'ō' => 'o',
    'ő' => 'o', 'œ' => 'oe',
    'Ó' => 'O', 'Ò' => 'O', 'Ô' => 'O', 'Ö' => 'Oe', 'Õ' => 'O', 'Ø' => 'O', 'Ō' => 'O',
    'Ő' => 'O', 'Œ' => 'OE',

    # u
    'ú' => 'u', 'ù' => 'u', 'û' => 'u', 'ü' => 'ue', 'ū' => 'u', 'ů' => 'u', 'ű' => 'u',
    'ũ' => 'u', 'ų' => 'u',
    'Ú' => 'U', 'Ù' => 'U', 'Û' => 'U', 'Ü' => 'Ue', 'Ū' => 'U', 'Ů' => 'U', 'Ű' => 'U',
    'Ũ' => 'U', 'Ų' => 'U',

    # y
    'ý' => 'y', 'ÿ' => 'y', 'ŷ' => 'y', 'ẏ' => 'y', 'ỳ' => 'y',
    'Ý' => 'Y', 'Ÿ' => 'Y', 'Ŷ' => 'Y', 'Ẏ' => 'Y', 'Ỳ' => 'Y',

    # c
    'ç' => 'c', 'ć' => 'c', 'č' => 'c', 'ĉ' => 'c', 'ċ' => 'c',
    'Ç' => 'C', 'Ć' => 'C', 'Č' => 'C', 'Ĉ' => 'C', 'Ċ' => 'C',

    # n
    'ñ' => 'n', 'ń' => 'n', 'ň' => 'n', 'ņ' => 'n', 'ŋ' => 'n',
    'Ñ' => 'N', 'Ń' => 'N', 'Ň' => 'N', 'Ņ' => 'N', 'Ŋ' => 'N',

    # ligatures and special
    'ß' => 'ss',  # German sharp S
    'ð' => 'd',   # Icelandic eth
    'Ð' => 'D',
    'þ' => 'th',  # Icelandic thorn
    'Þ' => 'Th',
    'æ' => 'ae', 'Æ' => 'AE', 'œ' => 'oe', 'Œ' => 'OE',

    # Polish and Eastern European letters
    'ł' => 'l', 'ń' => 'n', 'ś' => 's', 'ź' => 'z', 'ż' => 'z',
    'Ł' => 'L', 'Ń' => 'N', 'Ś' => 'S', 'Ź' => 'Z', 'Ż' => 'Z',

    # Romanian
    'ș' => 's', 'ț' => 't',
    'Ș' => 'S', 'Ț' => 'T',

    # Turkish
    'ğ' => 'g', 'Ğ' => 'G',
    'ı' => 'i', 'İ' => 'I',

    # Additional letters
    'ŕ' => 'r', 'Ŕ' => 'R',
    'ŧ' => 't', 'Ŧ' => 'T',
    'đ' => 'd', 'Đ' => 'D',

    # Other miscellaneous letters
    'ŉ' => 'n', 'ħ' => 'h', 'Ħ' => 'H', 'ů' => 'u', 'Ů' => 'U',
    'ſ' => 's', # Long S
    # Add more as needed
    );
	foreach my $char (keys %translate) {
	    $s =~ s/\Q$char\E/$translate{$char}/g;
	}
	$s = unidecode($s);

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
