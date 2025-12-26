Content-type:application/json; charset=UTF-8;
Access-Control-Allow-Origin: *

[<TMPL_LOOP NAME=events>
    {
        "id" : "<TMPL_VAR event_id>",
        "domain" : "https:<TMPL_VAR .source_base_url>",
        "url" : "https:<TMPL_VAR .source_base_url>programm/sendung/<TMPL_VAR event_id>.html#<TMPL_VAR event_uri escape=url>",
        "title" : "<TMPL_VAR full_title escape=IJSON>",
        "excerpt" : "<TMPL_VAR excerpt escape=IJSON>",
        "start" : "<TMPL_VAR start_date>T<TMPL_VAR start_time>:00",
        "end"   : "<TMPL_VAR end_date>T<TMPL_VAR end_time>:00",
        "series_name" : "<TMPL_VAR series_name escape=IJSON>",
        "image_url" : "<TMPL_VAR series_image_url escape=IJSON>",
        <TMPL_IF recurrence_date>"recurrence" : "<TMPL_VAR recurrence_weekday_name>, <TMPL_VAR recurrence_date_name>, <TMPL_VAR recurrence_time>",</TMPL_IF>
        "topic" : "<TMPL_VAR topic escape=IJSON>",
        "content" : "<TMPL_VAR content escape=IJSON>"
    }
    <TMPL_UNLESS "__last__">,</TMPL_UNLESS>
</TMPL_LOOP>]
