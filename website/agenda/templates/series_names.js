<TMPL_IF use_client_cache>Cache-Control: max-age=3600, must-revalidate
</TMPL_IF>Content-type:application/json; charset=UTF-8;

[
<TMPL_LOOP name=projects><TMPL_LOOP name=series_names>{"id":"<TMPL_VAR series_name>", "label":"<TMPL_VAR series_name>", "value":"<TMPL_VAR series_name>"} <TMPL_UNLESS last>,</TMPL_UNLESS>
</TMPL_LOOP></TMPL_LOOP>
]
