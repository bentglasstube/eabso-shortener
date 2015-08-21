package EABShortener;

use 5.010;
use utf8;
use strict;
use warnings;
use threads;

use Dancer ':syntax';
use Dancer::Plugin::Database;

our $VERSION = '1.1';

use Data::Validate::URI 'is_uri';
use LWP::UserAgent;
use HTML::TreeBuilder::Select;
use URI;

my $ua = LWP::UserAgent->new(
  timeout    => 5,
  parse_head => 0,
  agent      => config->{appname} . '/' . $VERSION
);

if ($ENV{DATABASE_URL}) {
  debug "Database URL: $ENV{DATABASE_URL}";

  my ($scheme, $user, $pass, $host, $port, $path) =
    ($ENV{DATABASE_URL} =~ m|^(\w+)://(.+?):(.+?)@(.+?):(\d+?)/(\w+)$|);

  my $driver = '';
  if ($scheme eq 'postgres') {
    $driver = 'Pg';
  }

  config->{plugins}{Database} = {
    driver   => $driver,
    database => $path,
    host     => $host,
    port     => $port,
    username => $user,
    password => $pass,
  };
}

my %ext_map = (
  'image/jpeg' => '.jpg',
  'image/png'  => '.png',
  'image/gif'  => '.gif',
  'text/plain' => '.txt',
  'text/html'  => '.html',
);

my @thumb_selectors = (
  'img#prodImage',        # amazon single
  'img#main-image',       # amazon multi
  '#comic img',           # xkcd
  'img.comic',            # qwantz
  'table.infobox img',    # wikipedia
);

sub get_extension {
  my ($type) = @_;

  return $ext_map{$type} if exists $ext_map{$type};
  return '';
}

sub get_title {
  my ($type, $body) = @_;

  if (not defined $type) {
    return 'Unknown link';
  } elsif ($type eq 'text/html') {
    if ($body =~ m|<title>(.*?)</title>|si) {
      my $title = $1;
      $title =~ s/\s+/ /g;
      $title =~ s/^\s+//;
      $title =~ s/\s+$//;

      $title = substr($title, 0, 99) . '…' if length($title) > 100;

      return $title;
    } else {
      return 'Untitled link';
    }
  } else {
    return $type;
  }
}

sub get_thumb {
  my ($uri, $type, $body) = @_;

  return $uri if $type =~ m{^image/};

  my $tree = HTML::TreeBuilder::Select->new_from_content($body);
  my $thumb;
  my $elem;

  if ($elem = $tree->look_down(_tag => 'link', rel => 'image_src')) {
    $thumb = $elem->attr('href');
  } elsif ($elem = $tree->look_down(_tag => 'meta', name => 'twitter:image')) {
    $thumb = $elem->attr('value');
  } elsif ($elem = $tree->look_down(_tag => 'meta', property => 'og:image')) {
    $thumb = $elem->attr('content');
  } else {
    foreach (@thumb_selectors) {
      if ($elem = $tree->select($_)) {
        $thumb = $elem->attr('src');
        last;
      }
    }
  }

  $tree->delete;

  return URI->new_abs($thumb, $uri)->as_string if $thumb;
  return undef;
}

sub get_links {
  my $after  = param('a');
  my $before = param('b');
  my $query  = param('q');
  my $user   = param('u');
  my $number = param('n') || 25;

  my $opts = {
    order_by => { desc => 'created' },
    limit    => $number,
  };

  my $where = {};
  $where->{title}       = { like => "%$query%" } if $query;
  $where->{user}        = $user                  if $user;
  $where->{created}{gt} = $after                 if $after;
  $where->{created}{lt} = $before                if $before;

  return [ database->quick_select('links', $where, $opts) ];
}

my @chars = split //, 'abcdefghijklmnopqrstuvwxyz0123456789';
post '/' => sub {
  content_type 'application/json';

  my $uri = param('uri');

  $uri = "http://$uri" unless $uri =~ m{^[a-z]+://}i;

  if (is_uri($uri)) {
    my $token = join '', map $chars[ int(rand(@chars)) ], 1 .. 6;

    my $resp = $ua->get($uri);

    if ($resp->is_success) {
      (my $type = $resp->header('Content-Type')) =~ s/;.*$//;

      $token .= get_extension($type);

      my $title = get_title($type, $resp->decoded_content);
      my $thumb = get_thumb($uri, $type, $resp->decoded_content);
      my $author = substr(param('user'), 0, 50) || 'Some asshole';

      database->quick_insert(
        links => {
          token   => $token,
          uri     => $uri,
          title   => $title,
          user    => $author,
          created => time,
          thumb   => $thumb,
        });

      async {
        if (defined $ENV{SLACK_HOOK_URL}) {
          $ua->post(
            $ENV{SLACK_HOOK_URL}, {
              payload => qq{
              {
                "text": "$title <http://eab.so/$token> ($author)",
                "username": "eab.so",
                "icon_emoji": ":bricky:"
              }
            },
            });
        }
      }
      ->detach();

      return to_json { result => "http://eab.so/$token" };
    } else {
      return to_json { error => $resp->status_line };
    }
  } else {
    return to_json { error => 'invalid uri' };
  }
};

get '/' => sub {
  template 'links', { links => get_links };
};

get '/json' => sub {
  content_type 'application/json';
  to_json get_links;
};

get '/rss' => sub {
  content_type 'text/xml';
  template 'rss', { links => get_links }, { layout => undef };
};

get '/crx' => sub {
  redirect 'https://chrome.google.com/webstore/detail/cdjnlghjdbiambiakngkffonbaeoikcn';
};

any '/new.pl' => sub {
  content_type 'application/json';
  return to_json { error => 'update extension' };
};

get '/:token' => sub {
  my $link = database->quick_select(links => { token => param('token') });
  if ($link) {
    redirect $link->{uri};
  } else {
    status 'not_found';
    template '404';
  }
};

any qr{.*} => sub {
  status 'not_found';
  template '404';
};

true;
