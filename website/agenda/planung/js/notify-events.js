if (window.namespace_notify_events_js) throw "stop"; window.namespace_notify_events_js = true;
"use strict";
function register_buttons() {
    $("#forms form").on('click', 'button', function( event ) {
        event.preventDefault();
        var form = $(this).closest('form');
        $.post("notify-events.cgi", form.serialize())
        .done( function(data) {
            var content = $(data).find("#content");
            $('#result').html(content);
            var formId = form.attr('id');
            $('#' + formId+" table").addClass("done");
        });
    });
}

function hide_details() {
    $('table.panel tbody').each(function(){
        $(this).children("tr.details").each(function() {
            $(this).hide();
        })
    })

    $('table.panel sprite-icon.toggle-rotate').on("click", function() {
        $(this).closest('tbody').children("tr.details").each(function() {
            $(this).toggle();
        })
    })
}

// init function
window.calcms ??= {};
window.calcms.init_notify_events = function(el) {
    hide_details();
    register_buttons();
};
