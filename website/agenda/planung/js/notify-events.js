if (window.namespace_notify_events_js) throw "stop"; window.namespace_notify_events_js = true;
"use strict";
function register_buttons() {
    $("#forms form").on('click', 'button', async function( event ) {
        event.preventDefault();
        var form = $(this).closest('form');
        var formData = new FormData(form.get(0));
        var formId = form.attr('id');
        let formTable = $('#' + formId + " table");
        formTable.find(".status").html('<sprite-icon name="progress"></sprite-icon>');
        $('#' + formId + ' table button').prop('disabled', true);
        let json = await postJson("notify-events.cgi", formData);
        if (!json) {
            formTable.find(".status").html('<sprite-icon name="error"></sprite-icon>');
            formTable.addClass("error");
            $('#' + formId + ' table button').prop('disabled', false);
            return;
        }
        showInfo("email send");
        formTable.find(".status").html('<sprite-icon name="check"></sprite-icon>');
        formTable.addClass("done");
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
