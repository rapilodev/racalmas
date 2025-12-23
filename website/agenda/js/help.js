if (window.namespace_help_js) throw "stop"; window.namespace_help_js = true;
"use strict";

function addToToc(selector) {
    $(selector).each(function() {
        if ($(this).hasClass('hide')) return;
        var title = $(this).text();
        var tag = $(this).prop('tagName');
        var span = 2;
        if (tag == 'H2') span = 4;
        if (tag == 'H3') span = 6;
        if (tag == 'H4') span = 8;
        var url = title;
        url = url.replace(/[^a-zA-Z]/g, '-')
        url = url.replace(/\-+/g, '-')
        $(this).append('<a name="' + url + '" />');
        $('#toc').append('<li style="margin-left:' + span + 'em"><a href="#' + url + '">' + title + '</a></li>')
    });
}

// init function
window.calcms ??= {};
window.calcms.init_help = function(el) {
    addToToc('#content h1,#content h2,#content h3,#content h4');
}