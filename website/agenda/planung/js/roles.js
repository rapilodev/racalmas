function add_user_role() {
    if ($('#new_user_role').css('display') == 'none') {
        $('.editor').show();
        $('#add_user_role_button').html('cancel add user role');
    } else {
        $('.editor').hide();
        $('#add_user_role_button').html('add user role');
    }
}

// init function
window.calcms ??= {};
window.calcms.init_roles = function(el) {
    $("input.disabled").attr('disabled', 'disabled');
    var width = 960 / ($("input.role").length);
    $("input.role").css('width', width + 'px');

    $('input[type="checkbox"]').click(
        function() {
            if ($(this).attr('value') == '1') {
                $(this).attr('value', '0');
            } else {
                $(this).attr('value', '1');
            }
        }
    );
};
