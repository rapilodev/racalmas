Content-type:application/json; charset=UTF-8;
Access-Control-Allow-Origin: *

[
<TMPL_LOOP name=projects><TMPL_LOOP name=series_names>{"id":"<TMPL_VAR series_name>", "label":"<TMPL_VAR series_name>", "value":"<TMPL_VAR series_name>"} <TMPL_UNLESS last>,</TMPL_UNLESS>
</TMPL_LOOP></TMPL_LOOP>
]
