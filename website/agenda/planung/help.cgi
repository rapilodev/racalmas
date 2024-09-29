# !/usr/bin/perl -w

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use URI::Escape();

use params();
use config();
use entry();
use log();
use template();
use auth();
use uac();
use studios();
use markup();
use localization();

#binmode STDOUT, ":utf8";

my $r = shift;
(my $cgi, my $params, my $error) = params::get($r);

my $config = config::get('../config/config.cgi');
my ($user, $expires) = auth::get_user($config, $params, $cgi);
return if ((!defined $user) || ($user eq ''));

my $user_presets = uac::get_user_presets(
    $config,
    {
        user       => $user,
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id}
    }
);
$params->{default_studio_id} = $user_presets->{studio_id};
$params = uac::setDefaultStudio($params, $user_presets);
$params = uac::setDefaultProject($params, $user_presets);

my $request = {
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params($config, $params),
    },
};
$request = uac::prepare_request($request, $user_presets);

$params = $request->{params}->{checked};

#process header
my $headerParams = uac::set_template_permissions($request->{permissions}, $params);
$headerParams->{loc} = localization::get($config, { user => $user, file => 'menu' });
template::process($config, 'print', template::check($config, 'default.html'), $headerParams);
return unless uac::check($config, $params, $user_presets) == 1;

my $toc = $headerParams->{loc}->{toc};

print q!
<style>
#content h1{
    font-size:1.6em;
}

#content h2{
    font-size:1.2em;
    padding-top:1em;
    padding-left:2em;
}

#content h3{
    font-size:1em;
    padding-left:4em;
}

#content h4{
    font-size:1em;
    padding-left:4em;
}

#content p{
    padding-left:6em;
    line-height:1.5em;
}

#content ul{
    padding-left:7em;
}

#content li{
    line-height:1.5em;
}

body #content{
    max-width:60em;
}

</style>

<script>
function addToToc(selector){
    $(selector).each(function(){
        if($(this).hasClass('hide'))return
        var title=$(this).text();
        var tag=$(this).prop('tagName');
        var span=2;
        if(tag=='H2')span=4;
        if(tag=='H3')span=6;
        if(tag=='H4')span=8;
        var url=title;
        url=url.replace(/[^a-zA-Z]/g,'-')
        url=url.replace(/\-+/g, '-')
        $(this).append('<a name="'+url+'" />');
        $('#toc').append('<li style="margin-left:'+span+'em"><a href="#'+url+'">'+title+'</a></li>')
    });
}

$(document).ready(function() {
    addToToc('#content h1,#content h2,#content h3,#content h4');
})
</script>
!;

print markup::creole_to_html(getHelp($headerParams->{loc}->{region}));

sub getHelp {
    my $region = shift;
    return getGermanHelp() if $region eq 'de';
    return getEnglishHelp();
}

sub getGermanHelp {
    return q{

<div id="toc"><h1 class="hide">Inhaltsverzeichnis</h1></div>

= Menü
== Login

Für das Login ist ein persönliches Konto für jeden Nutzer mit einem Passwort notwendig.

Persönliche Logins dürfen nicht weitergegeben werden, es können eigene Konten mit persönlichen Einstellungen für jeden Nutzer verwendet werden.

Am Ende einer Sitzung bitte ausloggen.

== Einstellungen

Hier können folgende persönliche Einstellungen vorgenomment werden:

* Auswahl der Sprache der Oberfläche (momentan Deutsch und Englisch)
* Auswahl der Farben für Sendungen, Plantermine, Konflikte, etc.
* Auswahl der Voreinstellungen für den Kalender
* Ändern des Passworts

== Projekte und Studios

Alle Sendereihen, Termine, Rechte und Einstellungen werden immer abhängig vom ausgewählen Projekt und Studio angezeigt.
Ein Projekt kann mehrere voneinander unabhängige Studios beinhalten.
Das Projekt und das Studio kann oben rechts ausgewählt werden.
Abhängig von seinen Rechten kann ein Nutzer in verschiedenen Projekten und Studios unterschiedliche Aktionen durchführen.

== Rechte
Einzelnen Nutzern können verschiedene Rollen im aktuellen Studio zugewiesen werden (z.B. Gast, Redaktion, Programmplanung, Studio Manager).
Es ist möglich eigene Rollen zu definieren und an Nutzer zu vergeben.

Jeder Nutzer sollte nur die Rechte zugewiesen bekommen, die er wirklich benötigt.

Dies vereinfacht die Benutzung, da Nutzer nur die für ihn wichtigen Punkte sehen und Fehlbedienungen ausgeschlossen werden können, z.B. versehentliches Löschen einer fremden Sendung.

Die Zuweisung von Rollen zu Nutzern ermöglicht ein verteiltes Arbeiten, z.B. jemand kümmert sich um die Sendeplanung und das Anlegen von Sendungen, Redaktionen können eigenständig Inhalte ihrer Sendungen bearbeiten.

Die zugewiesenen Rechte gelten immer nur für das gewählte Projekt und Studio. Die einzelnen Studios bestimmen selbständig, wer welche Rechte in ihrem Studio hat.

== Nutzer

Es können individuelle Benutzerkonten angelegt und bearbeitet werden.

Hier lässt sich die email-Addresse bearbeiten, ein Nutzer sperren oder löschen.

Die Berechtigungen des Nutzers können über ihm zugewiesene Rollen definiert werden.

== Sendezeiten

Hier können für ein Projekt und die Sendezeiten für mehrere Studios eingetragen werden.

Sendungen eines Studios lassen sich nur innerhalb der Sendezeiten des Studios anlegen.

Sendezeiten bestehen aus
* Datum und Zeit des Beginns des ersten Sendeblocks,
* Datum und Zeit des Endes des ersten Sendeblocks,
* in welchem Interval der Sendeblock stattfindet (täglich, wöchentlich, ...)
* dem geplanten Enddatum des Sendeblocks
* dem Studio, dass im Sendeblock sendet.

Komplexe Sendezeiten lassen sich über mehrere Definitionen definieren.

== Kalender

Der Kalender zeigt alle Sendungen und die Plantermine seiner Sendereihen an.

Links oben lässt sich der angezeigte Zeitraum auswählen.

Zeiten, in denen Termine für ein Studio angelegt werden können, werden gestrichelt angezeigt.

Für Termine wird der Status (live, vorproduziert, archiviert,...) in Form von Icons angezeigt.

Über die Suche kann eine Liste von Sendungen angezeigt werden, die den Suchtext enthalten.

Über Filter lassen sich Konflikte und Sendungen mit einem bestimmten Status farblich hervorheben.

Mögliche Ursachen für Konflikte:

* mehrere Sendungen zur selben Zeit
* mehrere Planermine zur selben Zeit
* eine Sendung und ein Plantermin einer anderen Sendereihe zur selben Zeit
* eine Sendung ist nicht mit einem Plantermin verknüpft

== Sendereihen

Der Menüpunkt "Sendereihe" zeigt eine Übersicht aller Sendereihen eines Studios an.
Sendereihen, die lange nicht gesendet wurden, können über "alte Sendungen" eingeblendet werden.

Eine Sendereihe umfasst
* eine Vorlage für das Anlegen neuer Sendungen,
* die Verwaltung von Planterminen
* die Mitglieder der Redaktion der Sendereihe.

Alle Redaktionsmitglieder einer Sendereihe können die Sendungen einer Sendereihe bearbeiten.

== Plantermine

Plantermine ermöglichen eine vorausschauende Planung ohne dass alle Sendungen einer Sendereihe separat angelegt werden müssen.
Bei Änderungen der Planung können alle Plantermine in einem einzelnen Schritt angelegt, verschoben oder gelöscht werden.

Plantermine können einzelne Termine oder sich wiederholende Termine sein, die innerhalb der Studio-Zeiten liegen müssen.

Plantermine werden im Kalender angezeigt, können aber erst bearbeitet oder veröffentlicht werden, wenn für sie eine Sendung angelegt wurde.
Sendungen sollten erst angelegt werden, wenn der Plantermin bestätigt wurde.

Sobald eine Sendung angelegt wurde, existiert sie unabhängig vom Plantermin. Eine nachträgliche Änderung der Plantermine hat keine Auswirkungen auf schon bestätigte und angelegte Sendungen.

= Aktionen

== Sendungen planen

Unter "Sendereihen" können Plantermine für eine ausgewählte Sendereihe eingetragen werden.

Plantermin anlegen:
* im Kalender beim Klick auf den gewünschten freien Zeitbereich innerhalb der Sendezeiten.
* Unter "Sendereihe" / "Planung" in der Liste der Plantermine

Plantermin löschen:
* im Kalender beim Klick mit der rechten Maustaste auf einen Plantermin.
* im Kalender beim Klick auf einen Plantermin, dann unter "Planungstermin löschen"
* Unter "Sendereihe" / "Planung" in der Luste der Plantermine

== Arten von Planterminen

==== 1. Einzeltermin
**Start**: das Datum und die Zeit des Termin.

**Dauer** : Anzahl in Minuten

==== 2. Wiederholungstermine mit fester Periode

**Start** : ein festes Datum und eine Zeit

**Dauer** : in Minuten

**wiederholt bis**: bis zu welchem Datum Plantermine erstellt werden sollen

**wie oft**: alle wieviel Tage oder Wochen die Sendung wiederholt wird

Beispiel: alle 2 Wochen

==== 3. Wiederholungstermine auf Basis der Woche im Monat

**Start** : ein festes Datum und eine Zeit

**Dauer** : in Minuten

**wiederholt bis**: bis zu welchem Datum Plantermine erstellt werden sollen

**Woche** : die wievielte Woche im Monat

**Wochentag**: welcher Wochentag

**wie oft**: jedes Mal, jedes 2te Mal,... Die Wiedeholung beginnt mit dem ausgewählten Starttermin.

Beispiel: jeden 5.Montag im Monat, jedes 2te Mal

==== 4. Ausnahmen

Wenn bestimmte geplante Termine nicht stattfinden sollen, können separate Ausnahmetermine über das Häkchen "Ausnahme" angelegt werden.

Ausnahmetermine erscheinen
* nicht als Plantermin im Kalender und
* durchgestrichen in der Liste der geplanten Termine einer Sendereihe.

für Einzeltermine: der Plantermin kann einfach gelöscht werden.

für Wiederholungstermine: der ausfallende Plantermin kann als zusätzlicher Einzel-Planungstermin definiert werden.

Es ist auch möglich, wiederholende Ausnahmen zu definieren. Beispiel:
* ein Plantermin alle 2 Wochen und zusätzlich
* ein Ausnahmetermin alle 3 Wochen

== Sendereihe anlegen

im Menüpunkt "Sendereihe" unter "Sendereihe hinzugügen"

== Sendereihe bearbeiten

im Menüpunkt "Sendereihe" per Klick auf die Sendereihe

beim Bearbeiten einer Sendung per "Sendereihe bearbeiten"

== Sendung anlegen

Um eine Sendung anzulegen, muss ein Plantermin für die Sendereihe der Sendung existieren.
Im Kalender kann dazu ein freier Sendetermin mit der Maus gewählt werden und ein Plantermin angelegt werden.
Existiert der Plantermin, kann per Klick auf den Plantermin eine neue Sendung angelegt werden.

Beim Anlegen einer Sendung wird die Vorlage aus der Sendereihe in die Sendung kopiert.
Solbald die Sendung angelegt wurde, kann die Sendung von der Redaktion der Sendereihe bearbeitet werden.

Für nummerierte Sendungen wird die Nummer der Episode automatisch ermittelt, falls eine vorherige Sendung eine Episode eingetragen hat.
Ist der Titel der Sendung identisch zu einer existierenden, wird sie automatisch als Wiederholung gekennzeichnet.

== Sendung bearbeiten

Nachdem eine Sendung angelegt wurde, kann sie im Kalender oder in der Liste der Sendungen der Sendereihe bearbeitet werden.

=== Sendebeschreibung

Dies umfasst einzelne Felder für den Titel, den Auszug, aktuelle Themen, die Sendebeschreibung und ein Bild.

Für Titel und Auszug existieren separate Felder, die von der Redaktion bearbeitet werden können,
falls die Redaktion keine Rechte für die Bearbeitung der Felder Titel und Auszug besitzt.

=== Status

Von der Planung bis zur Archivierung kann der aktuelle Status einer Sendung über StatusFelder geändert werden.
Im Kalender kann nach dem Status gefiltert werden.

Folgende Status-Felder gibt es:
* **Live-Sendung**: die Sendung ist keine Vorproduktion
* **veröffentlicht**: die Sendung ist auf der Webseite sichtbar
* **im Playout**: die Vorproduktion ist ins Playout-System eingetragen
* **Wiederholung**: die Sendung ist eine Wiederholung
* **archiviert**: nach der Sendung wurde der Mittschnitt archiviert, z.B. auf CBA, FRN
* **kein Google Import**: der Inhalt der Sendung soll nicht durch einen Google-Import überschrieben werden

=== Aktionen beim Bearbeiten einer Sendung

* Sendereihe bearbeiten: Vorlage, Planung, Redaktion der Sendereihe ändern
* Sendungen zeigen: alle Sendungen der Sendereihe zeigen
* in andere Sendereihe verschieben: die Sendung wird von der ausgewählten Sendereihe abgekoppelt und in eine andere Sendereihe verschoben.
* Mittschnitt runterladen: Sobald ein Mittschnitt für die Sendung existiert (nach Ausstrahlung) wird ein temporärer Link zum Mittschnitt erzeugt (momentan nur Piradio).
* Wiederholung von alter Sendung: Der Inhalt der Sendebeschreibung wird von einer auswählbaren existierenden Sendung kopiert.
* Erinnerung: Eine Mail zur Erinnerung wird generiert und in einem externen Email-Programm anagezeigt.
* Änderungen: Eine Liste der Änderungen an dem Sendeeintrag
* Löschen: Die Sendung und ihre Beschreibung wird gelöscht
* Programmansicht: die Sendung wird im Programmplan angezeigt.

=== Bedingungen zum Bearbeiten einer Sendung

* Die Sendung muss einer Sendereihe zugeordnet sein.
* Die Sendung muss innerhalb der Sendezeiten des ausgewählten Projekts und Studios liegen.
* Der Benutzer muss der Redaktion der Sendereihe zugeordnet sein
* Der Benutzer benötigt Redaktionsrechte

};
}

sub getEnglishHelp {
    return q{
<div id="toc"><h1 class="hide">Table of Contents</h1></div>

= Menu
== Login

To log in a account and a password is required for each user.
An account allows to set individual settings for each user.
Personal accounts should not be shared.
Please log out at end of each session.

== Settings

A user can customize following user settings:

* The language of the user interface (English, German)
* Colors for broadcasts, schedules, conflicts and more.
* default time range displayed at the calendar
* change the password

== Projects and Studios

All Series, Dates, Permissions and Settings are displayed depending on the selected project and studio.
A project consists of one or more studios.
Project and studio can be selected at the top right of each page.
A user can execute different actions depending on the permissions the user has for the selected project and studio.

== Permissions
A user can be assigned to different roles for a selected project and studio
(for example Guest, Editor, Program Scheduler, Studio Manager).
A role is a set of selected permissions.
It is possible to define new roles and assign them to selected users.

Each user should get only the permissions he or she really needs.
This eases using the system, due to a user only sees the actions that are assigned to the role.
It can prevent failures, for example deleting a broadcast the user is not assigned to.

By assigning roles to users the workflow can be done by multiple users with different roles.
For example one can schedule the program, while editors can fill in the content for their broadcasts.

Permissions of an user can be individually set for each project and studio.

== Users

At the menu Users you can edit the user accounts.
User accounts can be locked or deleted, one can edit the email address and assign roles to the user account.

== Time Slots

At the Time Slots menu you can assign time spans for each studio of the project.
One can create broadcasts only within the broadcast date ranges of the selected studio.
This prevents to create broadcasts out of the time slots defined.

Time Slot definition consists of
* start date and time of the first time slot,
* end date and time of the first time slot,
* The interval of the time slot (daily, weekly, and more)
* the end date of the last time slot
* the studio which broadcasts at the selected time slot.

You can define multiple time slots for each studio

== Calendar

The calendar shows all broadcasts and schedules of the series assigned to the selected project and studios.

You can select the displayed time range at the upper left.

Time slots of the studio are displayed dashed.

There are icons to show the status of each broadcast (live, preproduced, archived,...).

By using the search field one can find a list of broadcasts and schedules containing the search value.

There are filters to mark conflicts and status by different colors.

Possible conflicts:

* multiple broadcasts at the same time
* multiple schedules at the same time
* a broadcast at the same time as a schedule of another series.
* a broadcast is not assigned to a schedule or a series.

== Series

The series menu gives an overview of all series of the selected project and studio.
Series that have no broadcasts in the previous weeks can be displayed by "old series" button.

The series consist of
* a template for creating new broadcasts
* the series schedule
* the editors of the series

All editors of a series can edit the broadcasts of a series.

== Schedule

schedule dates allow to schedule broadcasts without separately creating single broadcasts for a series.
Schedule dates can be created, moved or deleted in a single step.

Schedule dates can be single dates or recurring dates. Both have to be inside the time slots of the project and studio.

Schedule dates are displayed in the calendar. One can create a broadcasts from an existing schedule date only. This should be done if the schedule date has been confirmed to avoid unneccessary editing of the date.

If a broadcast entry has been created it exists independent on the schedule date. If the schedule date is changed after creating a broadcast from the broadcast will not be changed.

= Actions

== schedule Broadcasts

At "Series" menu schedule dates can be edited for the selected series.

create schedule dates:
* at Calendar click on a free date of one of the displayed time slots. (Studio time slots are to be defined before.)
* at Series / Schedule one can edit the schedule

delete schedule dates:
* at Calendar right mouse clock on a schedule date.
* at Calendar select a schedule date, then select the remove schedule button.
* At Series / Schedule one can edit the schedule

== Types of schedule dates

==== 1. single date
**Start**: the date and time of the single schedule

**Duration** : in minutes

==== 2. Recurring Schedule with fix interval

**Start** : the start date and time of the first broadcast

**Duration** : in minutes

**End**: date of the last broadcast

**interval**: Interval of recurrence (daily, weekly, ...)

==== 3. Recurring Schedule based on week of month

**Start** : the start date and time of the first broadcast

**Duration** : in minutes

**End**: date of the last broadcast

**Week of Month** : from first to fifth week of month

**Weekday**: the weekday

**every nth time**: if not every date of the recurring schedule should be used, one can select to use the 5th Monday of a month, each other time.

==== 4. Exceptions

On having multiple recurring schedules one can use exceptions to define single or recurring dates a broadcast should not happen.

Exception schedule dates are
* not displayed in the calendar
* displayed striked through at the list of scheduled dates of a series.

Exceptions for single date : the schedule date will be deleted

Exceptions for recurring schedule dates: a single exception will be created for the date the broadcast will not take place at.

Additionally it is possible to create recurring exceptions.
Example 1: a schedule every two weeks and an exception schedule every three weeks
Example 2: a daily schedule for the whole year and an exception schedule from first until last of May.

== create series

At menu "Series" click "add Series" button

== edit Series

At menu "Series" select the series to edit

At editing a broadcast event, click on "edit series"

== create a broadcast event

To create a broadcast event a schedule has to be created for the series first.
At calendar choose a free time slot and create a schedule.
At calendar select the schedule date to create a new broadcast.

On creating broadcast Bthe template of the series will be copied to the broadcast.
Once the broadast has been created the entry can be edited by the editors of the broadcast.

The number of the episode will be increased automatically if "count episodes" has been selected at series template.
A broadcast event will be marked as recurring event if the title of the broadcast is the same as the title of an existing broadcast.

== edit a broadcast

Once a broadcast has been created, it can be edited by selecting at Calendar or at list of broadcasts at Series.

=== Broadcast description

There are fields for the title, the excerpt, current topice, a textual description and an image.

There are separate fields for title and excerpt that can be used to be edited by editors, in case editors have not the
permission to edit title and excerpt themself.
In general editing each field can be selected for each role of the permission sets.

=== Status

The current status of a broadcast can be set to communicate it to other users.
The status can be filtered at Calendar.

There are following status fields:
* **Live**: This is a live broadcast (no preproduction)
* **published**: The broadcast is scheduled and published at the public broadcast schedule
* **playout**: The preproduction has been scheduled at the playout system
* **rerun**: The broadcast is a rerun of an existing broadcast
* **archived**: the broadcast audio has been archived

=== Actions on editing a broadcast event

* edit series: change template, schedule and editors of the series
* show events: show all broadcast events of the same series
* move to other series: the broadcast will be moved to another series.
* download record: creates a temporary link to download the record.
* copy existing event: the description will be copied from an existing event to the current one.
* reminder: a mail to remind the editors will be opened in an external mail program.
* changes: shows the list of changes at the selected event
* delete: deletes the broadcast and its description
* show event: show the event at the publich program

=== Preconditions to create/add a series

* The broadcast event has to be assigned to a series.
* the broadcast time has to be inside the time slots of the selected project and studios.
* The user has to be a member of the editors of the series.
* The user needs permissiosn to "edit series he/she is assigned to"

};

}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    $checked->{exclude} = 0;
    entry::set_numbers($checked, $params, [
        'id', 'project_id', 'studio_id', 'default_studio_id' ]);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    return $checked;
}

