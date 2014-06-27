function makeLinkElem(link) {
  console.log(link.created);

  var time = new Date(link.created * 1000).toISOString().replace('T', ' ').replace(/\..*/, '');

  var html = '<li style="display: none;">';
  if (link.thumb) html += '<a href="' + link.uri + '"><img class="thumb" src="' + link.thumb + '" alt="thumbnail"></a>';
  html += '<p class="link"><a href="/' + link.token + '">' + link.title + '</a></p>';
  html += '<p class="author">' + link.user + '</p>';
  html += '<p class="date">' + time + '</p>';
  html += '</li>';

  return html;
}

function saveSettings() {
  console.log('save settings');

  $.cookie('settings-name', $('#settings-name').val(), { expires: 3650 });

  $('#settings').modal('hide');
}

function hasQueryString() {
  return window.location.href.indexOf('?') != -1;
}

$(document).ready(function() {
  $('#settings-name').val($.cookie('settings-name'));

  $('#share').submit(function(e) {
    $('#waiting').show();
    $('.error').hide();

    var body = {
      uri:  $('#url').val(),
      user: $.cookie('settings-name'),
    };

    $.post('/', body, function(data) {
      $('#url').val('');
      $('#waiting').hide();

      if (data.error) {
        $('.error').show();
        $('.error').text(data.error);
      } else {
        $('.error').hide();
      }
    });

    e.preventDefault();
  });

  if (!hasQueryString()) {
    $(window).scroll(function() {
      if ($(window).scrollTop() == $(document).height() - $(window).height()) {
        $.get('/json?b=' + oldest, function(data) {
          if (data.length > 0) {
            for (i in data) {
              $('#links').append(makeLinkElem(data[i]));
              oldest = data[i].created;
            }
            $('li').fadeIn();
          }
        });
      }
    });

    (function refresh() {
      $.ajax({
        url: '/json?a=' + newest,
        success: function(data) {
          if (data.length > 0) {
            for (i in data) {
              $('#links').prepend(makeLinkElem(data[i]));
            }
            newest = data[0].created;
            $('li').fadeIn();
          }
        },
        complete: function() {
          setTimeout(refresh, 1000);
        },
      });
    })();
  }

  $('#settings form').submit(function(e) {
    saveSettings();
    e.preventDefault();
  });

  $('#save').click(function(e) {
    saveSettings();
    e.preventDefault();
  });
});
