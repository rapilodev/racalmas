if (window.namespace_notify_events_js) throw "stop"; window.namespace_notify_events_js = true;
"use strict";
function register_buttons() {
    $("#forms form").on('click', 'button', async function( event ) {
        event.preventDefault();
        var form = $(this).closest('form');
        var formData = new FormData(form.get(0));
        var formId = form.attr('id');
        let formTable = $('#' + formId + " table").removeClass("error","done");
        let json = await postJson("notify-events.cgi", formData);
        if (!json) {
            formTable.addClass("error");
            return;
        }
        showInfo("email send");
        formTable.addClass("done");
        $('#' + formId + ' table button').prop('disabled', true);
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
