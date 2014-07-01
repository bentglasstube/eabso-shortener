create table if not exists links (
  "token"   varchar(16)   not null primary key,
  "uri"     varchar(1024) not null,
  "title"   varchar(150)  not null,
  "user"    varchar(50)   not null,
  "created" integer       not null,
  "thumb"   text
);

create index created_desc on links (
  created desc
);
