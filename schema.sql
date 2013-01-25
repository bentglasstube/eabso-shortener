create table if not exists links (
  token   text    not null primary key,
  uri     text    not null,
  title   text    not null,
  user    text    not null,
  created integer not null
);

create index if not exists created_desc on links (
  created desc
);

alter table links add column thumb text;
