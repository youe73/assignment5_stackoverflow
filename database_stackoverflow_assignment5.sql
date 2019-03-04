/*drop database stackoverflow;*/
/*
create database stackoverflow DEFAULT CHARACTER 
SET utf8 DEFAULT COLLATE utf8_general_ci;

use stackoverflow;

create table badges (
  Id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  UserId INT,
  Name VARCHAR(50),
  Date DATETIME
);

CREATE TABLE comments (
    Id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    PostId INT NOT NULL,
    Score INT NOT NULL DEFAULT 0,
    Text TEXT,
    CreationDate DATETIME,
    UserId INT 
);

CREATE TABLE post_history (
    Id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    PostHistoryTypeId SMALLINT NOT NULL,
    PostId INT NOT NULL,
    RevisionGUID VARCHAR(36),
    CreationDate DATETIME,
    UserId INT,
    Text TEXT
);
CREATE TABLE post_links (
  Id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  CreationDate DATETIME DEFAULT NULL,
  PostId INT NOT NULL,
  RelatedPostId INT NOT NULL,
  LinkTypeId INT DEFAULT NULL
);


CREATE TABLE posts (
    Id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    PostTypeId SMALLINT,
    AcceptedAnswerId INT,
    ParentId INT,
    Score INT NULL,
    ViewCount INT NULL,
    Body text NULL,
    OwnerUserId INT,
    LastEditorUserId INT,
    LastEditDate DATETIME,
    LastActivityDate DATETIME,
    Title varchar(256),
    Tags VARCHAR(256),
    AnswerCount INT DEFAULT 0,
    CommentCount INT DEFAULT 0,
    FavoriteCount INT DEFAULT 0,
    CreationDate DATETIME
);

CREATE TABLE tags (
  Id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  TagName VARCHAR(50) CHARACTER SET latin1 DEFAULT NULL,
  Count INT DEFAULT NULL,
  ExcerptPostId INT DEFAULT NULL,
  WikiPostId INT DEFAULT NULL
);


CREATE TABLE users (
    Id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    Reputation INT NOT NULL,
    CreationDate DATETIME,
    DisplayName VARCHAR(50) NULL,
    LastAccessDate  DATETIME,
    Views INT DEFAULT 0,
    WebsiteUrl VARCHAR(256) NULL,
    Location VARCHAR(256) NULL,
    AboutMe TEXT NULL,
    Age INT,
    UpVotes INT,
    DownVotes INT,
    EmailHash VARCHAR(32)
);

CREATE TABLE votes (
    Id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    PostId INT NOT NULL,
    VoteTypeId SMALLINT,
    CreationDate DATETIME
);

create index badges_idx_1 on badges(UserId);

create index comments_idx_1 on comments(PostId);
create index comments_idx_2 on comments(UserId);

create index post_history_idx_1 on post_history(PostId);
create index post_history_idx_2 on post_history(UserId);

create index posts_idx_1 on posts(AcceptedAnswerId);
create index posts_idx_2 on posts(ParentId);
create index posts_idx_3 on posts(OwnerUserId);
create index posts_idx_4 on posts(LastEditorUserId);

create index votes_idx_1 on votes(PostId);


SET GLOBAL local_infile = 1;
LOAD XML INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Badges.xml' INTO TABLE badges;
LOAD XML INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Comments.xml' INTO TABLE comments;
LOAD XML INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/PostHistory.xml' INTO TABLE post_history;
LOAD XML INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/PostLinks.xml' INTO TABLE post_links;
LOAD XML INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Posts.xml' INTO TABLE posts;
LOAD XML INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Tags.xml' INTO TABLE tags;
LOAD XML INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Users.xml' INTO TABLE users;
LOAD XML INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Votes.xml' INTO TABLE votes;

ALTER TABLE `stackoverflow`.`posts` 
ADD COLUMN `Comments` JSON NULL AFTER `CreationDate`;
*/

use stackoverflow;

DROP procedure if exists `denormalizeComments`;
DROP procedure if exists `addcomments`;
DROP procedure if exists `view_select`;
DROP trigger if exists `after_comments_insert`;
DROP trigger if exists insertview; 
DROP VIEW IF EXISTS query_view;
drop table if exists interactionByUsers;
DROP procedure IF EXISTS `materialized_view_insert`;

/*excercise 1
Write a stored procedure denormalizeComments(postID) that moves all comments for a post (the parameter) into a json array 
on the post.*/

DROP procedure IF EXISTS `denormalizeComments`;
DELIMITER $$
CREATE PROCEDURE `denormalizeComments` (p_postID INT)
BEGIN
update posts set Comments = (select JSON_ARRAYAGG(Text) from 
comments where PostId = p_postID group by PostId) where Id = p_postID;
END$$
DELIMITER ;

call denormalizeComments(3);
select Comments from posts limit5;

/*excercise 2
Create a trigger such that new adding new comments to a post triggers an insertion of that comment 
in the json array from exercise 1.*/

DROP TRIGGER if exists after_comments_insert;
DELIMITER $$
create trigger after_comments_insert after insert on comments
for each row
BEGIN 
call denormalizeComments(NEW.PostId); /*NEW keyword because it is after the update*/
END$$
DELIMITER ;

show triggers;


/*excercise 3
Rather than using a trigger, create a stored procedure to add a comment to a post 
- adding it both to the comment table and the json array*/

DROP procedure IF EXISTS `addcomments`;
DELIMITER $$
CREATE PROCEDURE `addcomments` (in_postID INT, add_text TEXT, user_post INT)
BEGIN
insert into comments (PostId, Score, Text, CreationDate, UserId) values 
(in_postID,1,add_text,now() ,user_post);
END$$
DELIMITER ;

call addcomments(11,"New comments in excercise3", 28);

/*excercise 4
Make a materialized view that has json objects with questions and its answeres, 
but no comments. Both the question and each of the answers must have the display name of the user, 
the text body, and the score.*/

drop table if exists interactionByUsers;
create table interactionByUsers(
 Id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
 categorytext json
);

DROP VIEW IF EXISTS query_view;
create view query_view as 
select JSON_OBJECT("name",DisplayName, "score",posts.Score, "type",PostTypeId, "textbody",JSON_ARRAYAGG(body)) as jsobject
from posts, users, comments 
where UserId = users.Id AND posts.Id = PostId group by users.Id;

DROP procedure IF EXISTS `materialized_view_insert`;
DELIMITER $$
create procedure `materialized_view_insert` ()
BEGIN
insert into interactionByUsers (categorytext) values 
((select JSON_OBJECT("name",DisplayName, "score",posts.Score, "type",PostTypeId, "textbody",JSON_ARRAYAGG(Body)) as jsobject
from posts, users, comments 
where UserId = users.Id AND posts.Id = PostId group by users.Id));
END$$
DELIMITER ;


DROP trigger if exists insertview; 
DELIMITER $$
create trigger insertview after update on posts
for each row
BEGIN 
call materialized_view_insert(); 
END$$
DELIMITER ;

show triggers;


/*
Exercise 5
Using the materialized view from exercise 4, create a stored procedure with one parameter keyword, 
which returns all posts where the keyword appears at least once, and where at least two comments mention the keyword as well.
*/

drop procedure if exists `parameterkeyword`;
DELIMITER $$
create procedure `parameterkeyword`(keyword Text)
BEGIN
select * from interactionByUsers where categorytext in (select categorytext->'$.text'='%keyword%'
AND categorytext->'$.text'>=1);
END$$
DELIMITER ;

drop procedure if exists `postskeyword`;
DELIMITER $$
create procedure `postskeyword`(keyword Text)
BEGIN
select * from query_view where jsobject->'$.text'='%keyword%'>=2;
END$$
DELIMITER ;

call parameterkeyword("taste");
call postskeyword("coffe");





