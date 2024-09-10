#!/usr/bin/perl
print "Content-type:text/plain\n\nAccess denies.";
exit;
__END__

<config>

Define DOMAIN               piradio.de
Define BASE_DIR             /home/radio/${DOMAIN}

# default project from database
project                     88vier
domain                      ${DOMAIN}

<filter>
    projects_to_exclude     corax,Nachtprogramm,Austausch
    locations_to_exclude    piradio_corax,ansage,potsdam,colabo,piradio_corax
</filter>

<controllers>
    # controller base directory
    domain                  /agenda/

    # customize controller URLs
    calendar                kalender
    event                   sendung
    events                  sendungen
    comments                kommentare
    ical                    ical
    atom                    atom
    rss                     rss
</controllers>

<locations>
    temp_dir                ${BASE_DIR}/temp/

    # URLs of the program page the agenda should be injected into(done by preload_agenda.pl)
    # this is the page containing calcms_menu, and other ids
    source_url_http         https://${DOMAIN}/calcms/
    source_url_https        https://${DOMAIN}/calcms/

    # feed base url
    source_base_url         https://${DOMAIN}/
    local_base_url          /agenda/
    editor_base_url         /agenda/planung/
    widget_render_url       /programm

    # ajax
    base_domain             https://${DOMAIN}/
    base_url                /agenda/?
    base_dir                ${BASE_DIR}/agenda/
    static_files_url        /agenda/

    # images
    local_media_dir         ${BASE_DIR}/media/
    local_media_url         /media/
    thumbs_url              /thumbs/
    icons_url               /icons/

    # archives
    local_archive_dir       /home/radioarchiv/${DOMAIN}/
    local_archive_url       http://${DOMAIN}/rcive/

    # listen
    listen_dir              /home/radioarchiv/${DOMAIN}/
    listen_url              https://${DOMAIN}/listen/

    # upload
    local_audio_recordings_dir ${BASE_DIR}/recordings/recordings/
    local_audio_recordings_url /recordings/

    # multi language support
    admin_pot_dir           ${BASE_DIR}/agenda/planung/pot/
    email                   koordination@radiopiloten.de
</locations>

<permissions>
    result_limit            500

    # limit creating comments in days before and after start of event
    no_new_comments_before  10
    no_new_comments_after   60

    hide_event_images       1
</permissions>

<access>
    hostname                localhost
    port                    3306
    database                calcms

    username                calcms_read
    password                Ayahdei2

    username_write          calcms_write
    password_write          aiJ3aeHa
</access>

<date>
    time_zone               Europe/Berlin
    language                de
    day_starting_hour       6
</date>

<mapping>
    <events>
        <location>
            piradio         Pi Radio
            potsdam         Frrapo
            ansage          Studio Ansage
            colabo          CoLaboRadio
            dt64            DT64 Festival
            frb             Freies Radio Berlin
            woltersdorf     Radio Industry
        </location>
    </events>
</mapping>

no_result_message           Pi-Radio sendet innerhalb der Freien Radios – Berlin-Brandenburg<br>jede Woche von Donnerstag um 6:00 Uhr bis Freitag um 6:00 Uhr.
events_title                Pi Radio: Berliner Stimmen und ihre Musik
events_description          Freies Radio aus Berlin, immer Mittwoch und Donnerstag von 19:00 bis 06:00 auf UKW 88,4 MHz(Berlin) und 90,7 MHz(Potsdam).

</config>

