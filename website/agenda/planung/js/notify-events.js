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

    $('table.panel img.toggle').on("click", function() {
        if( $(this).attr("src").indexOf("arrow-up") < 0 ){
            $(this).attr("src", "image/dark/arrow-up.svg");
        } else {
            $(this).attr("src", "image/dark/arrow-down.svg");
        }
        $(this).closest('tbody').children("tr.details").each(function() {
            $(this).toggle();
        })
    })
}


$(document).ready(function() {
    hide_details();
    register_buttons();
});

