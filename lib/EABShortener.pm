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

use constant PAGE_SIZE => 25;

sub get_links {
  my ($where) = @_;

  my $page = params->{p} || 1;
  my $opts = {
    order_by => { desc => 'created' },
    limit    => join(',', ($page - 1) * PAGE_SIZE, PAGE_SIZE),
  };

  return [ database->quick_select('links', $where, $opts) ];
}

get '/' => sub {
  template 'links', { links => get_links {} };
};

my @chars = split //, 'abcdefghijklmnopqrstuvwxyz0123456789';
post '/' => sub {
  if (is_uri(params->{uri})) {
    my $token = join '', map $chars[int(rand(@chars))], 1 .. 6;

    my $title;
    my $resp = $ua->get(params->{uri});
    (my $type = $resp->header('Content-Type')) =~ s/;.*$//;

    if ($resp->is_error) {
      $title = $resp->status_line;
    } else {
      $title = get_title($type, $resp->content);
      $token .= get_extension($type);
    }

    my $thumb;
    if ($type =~ m{^image/}i) {
      $thumb = params->{uri};
    }

    database->quick_insert(links => {
      token   => $token,
      uri     => params->{uri},
      title   => $title,
      user    => params->{user} || 'Some asshole',
      created => time,
      thumb   => $thumb,
    });

    content_type 'application/json';
    return to_json { result => "http://eab.so/$token" };
  } else {
    content_type 'application/json';
    return to_json { error => 'invalid uri' };
  }
};

get '/rss' => sub {
  content_type 'text/xml';

  my @links = database->quick_select(links => {}, { 
    order_by => { desc => 'created' }, 
    limit => PAGE_SIZE,
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

get '/history' => sub {
  template 'links', { links => get_links {} };
};

get '/history/:year' => sub {
  template 'links', { links => get_links {
    created => { ge => 0 },
    created => { le => 0 },
  }};
};

get '/history/:year/:month' => sub {
  template 'links', { links => get_links {
    created => { ge => 0 },
    created => { le => 0 },
  }};
};

get '/search' => sub {
  my $q = params->{query} || '';

  template 'links', { links => get_links {
    title => { like => "%$q%" },
  }};
};

get '/by/:author' => sub {
  template 'links', { links => get_links {
    user => params->{author},
  }};
};

get '/:token' => sub {
  my $link = database->quick_select(links => { token => params->{token} });
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
