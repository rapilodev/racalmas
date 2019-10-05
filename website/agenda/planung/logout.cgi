#!/usr/bin/perl

print qq{HTTP/1.0 401 Unauthorized
Request Version: HTTP/1.0
Response Code: 401
WWW-Authenticate: Digest realm="radio agenda", algorithm=MD5, domain="/admin/ http://piradio.de/agenda/admin/", qop="auth"
};
