$(document).ready(function() {
  $('form').submit(function(e) {
    $('#waiting').show();
    $('.error').hide();

    var uri = $('#url').val();

    $.post('/', { uri: uri }, function(data) {
      if (data.error) {
        $('#url').val('');
        $('#waiting').hide();
        $('.error').show();
        $('.error').text(data.error);
      } else {
        location.reload();
      }
    });

    e.preventDefault();
  });
});
