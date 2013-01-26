function makeLinkElem(link) {
  console.log(link.created);

  var time = new Date(link.created * 1000).toISOString().replace('T', ' ').replace(/\..*/, '');

  var html = '<li>';
  if (link.thumb) html += '<a href="' + link.uri + '"><img class="thumb" src="' + link.thumb + '" alt="thumbnail"></a>';
  html += '<p class="link"><a href="' + link.uri + '">' + link.title + '</a></p>';
  html += '<p class="author">' + link.user + '</p>';
  html += '<p class="date">' + time + '</p>';
  html += '</li>';

  return html;
}

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

  $('#more').click(function(e) {
    $.get('/json?b=' + oldest, function(data) {
      if (data.length == 0) {
        $('#more').parent().hide();
      } else {
        for (i in data) {
          $('#links').append(makeLinkElem(data[i]));
          oldest = data[i].created;
        }

        $('#more').attr('href', '?b=' + oldest);
      }
    });

    e.preventDefault();
  });
});
