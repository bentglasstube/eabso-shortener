package EABShortener;
use Dancer ':syntax';
use Dancer::Plugin::Database;

our $VERSION = '1.1';

use Data::Validate::URI 'is_uri';
use LWP::UserAgent;

my $ua = LWP::UserAgent->new(timeout => 5, agent => config->{appname} . '/' . $VERSION);
my %ext_map = (
  'image/jpeg' => '.jpg',
  'image/png'  => '.png',
  'image/gif'  => '.gif',
  'text/plain' => '.txt',
  'text/html'  => '.html',
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
      return $1;
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

  return;
}

get '/' => sub {
  my $page = param('p') || 1;
  my $query = param('q');
  my $author = param('a');

  my $opts = {
    order_by => { desc => 'created' },
    limit    => join(',', ($page - 1) * config->{page_size}, config->{page_size}),
  };

  my $where = {};

  $where->{title} = { like => "%$query%" } if $query;
  $where->{user} = $author if $author;

  my $links = [ database->quick_select('links', $where, $opts) ];

  template 'links', { links => $links };
};

my @chars = split //, 'abcdefghijklmnopqrstuvwxyz0123456789';
post '/' => sub {
  content_type 'application/json';

  my $uri = param('uri');

  $uri = "http://$uri" unless $uri =~ m{^[a-z]+://}i;

  if (is_uri($uri)) {
    my $token = join '', map $chars[int(rand(@chars))], 1 .. 6;

    my $resp = $ua->get($uri);

    if ($resp->is_success) {
      (my $type = $resp->header('Content-Type')) =~ s/;.*$//;

      $token .= get_extension($type);

      my $title = get_title($type, $resp->content);
      my $thumb = get_thumb($uri, $type, $resp->content);

      database->quick_insert(links => {
        token   => $token,
        uri     => $uri,
        title   => $title,
        user    => param('user') || 'Some asshole',
        created => time,
        thumb   => $thumb,
      });

      return to_json { result => "http://eab.so/$token" };
    } else {
      return to_json { error => $resp->status_line };
    }
  } else {
    return to_json { error => 'invalid uri' };
  }
};

get '/rss' => sub {
  content_type 'text/xml';

  my @links = database->quick_select(links => {}, { 
    order_by => { desc => 'created' }, 
    limit => config->{page_size},
  });
  template 'rss', { links => \@links }, { layout => undef };
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
