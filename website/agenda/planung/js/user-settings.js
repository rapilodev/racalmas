var selectedId;

$(document).ready(function() {
    $('input.color').click(function() {
        selectedId = ($(this).attr('id'));
        showColors();
    });
});

function showColors() {
    var colors = [ '#ef9a9a', '#f48fb1', '#ce93d8', '#b39ddb', '#9fa8da',
            '#90caf9', '#81d4fa', '#80deea', '#80cbc4', '#a5d6a7',
            '#c5e1a5', '#e6ee9c', '#fff59d', '#ffe082', '#ffcc80',
            '#ffab91', '#bcaaa4', '#b0bec5', '#bdc3c7', '#dde4e6',
            '#eeeeee', ];

    var content = '';
    for ( var c in colors) {
        var value = colors[c];
        content += '<div class="col" value="'+value+'" style="background:'+value+';"> </div>';
    }
    content += '<br style="clear:both">'

    $("#colors").html(content);
    $("#colors div.col").click(function() {
        var color = $(this).attr("value");
        $('#' + selectedId).css('background', color);
        $('#' + selectedId).attr('value', color);
    });
}
