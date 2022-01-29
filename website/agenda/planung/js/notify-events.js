function register_buttons() {
    $("#forms form").on('click', 'button', function( event ) {
        event.preventDefault();
        var form = $(this).closest('form');
        $.post("notify-events.cgi", form.serialize())
        .done( function(data) {
            var content = $(data).find("#content");
            $('#result').html(content);
            var formId = form.attr('id');
            $('#'+formId+" .mailHeader").addClass("done");
        });
    });
}

$(document).ready(function() {
    register_buttons();
});

