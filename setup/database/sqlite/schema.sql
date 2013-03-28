-- execute as:
-- sqlite3 nnexus.db < schema.sql
-- also consult the README file

-- Table structure for table categories
DROP TABLE IF EXISTS categories;
CREATE TABLE categories (
  categoryid integer primary key AUTOINCREMENT,
  categoryname varchar(100) NOT NULL DEFAULT '',
  externalid text,
  scheme varchar(50) NOT NULL DEFAULT ''
);

-- Table structure for table classification
DROP TABLE IF EXISTS classification;
CREATE TABLE classification (
  objectid int(11) NOT NULL DEFAULT '0',
  class text,
  scheme varchar(50) DEFAULT NULL
);

-- Table structure for table concepthash
DROP TABLE IF EXISTS concepthash;
CREATE TABLE concepthash (
  firstword varchar(255) NOT NULL DEFAULT '' PRIMARY KEY,
  concept varchar(255) NOT NULL DEFAULT '',
  objectid int(11) NOT NULL DEFAULT '0'
);

-- Table structure for table domain
DROP TABLE IF EXISTS domain;
CREATE TABLE domain (
  domainid integer primary key AUTOINCREMENT,
  name varchar(30) NOT NULL DEFAULT '' UNIQUE,
  urltemplate varchar(100) DEFAULT NULL,
  code varchar(2) DEFAULT NULL,
  priority varchar(30) DEFAULT '',
  nickname varchar(50) DEFAULT NULL
);

-- Table structure for table inv_dfs
DROP TABLE IF EXISTS inv_dfs;
CREATE TABLE inv_dfs (
  id int(11) DEFAULT '0',
  word_or_phrase tinyint(4) DEFAULT '0',
  count int(11) DEFAULT '0'
);
CREATE INDEX invididx ON inv_dfs(id);

-- Table structure for table inv_idx
DROP TABLE IF EXISTS inv_idx;
CREATE TABLE inv_idx (
  id int(11) DEFAULT '0',
  word_or_phrase tinyint(4) DEFAULT '0',
  objectid int(11) DEFAULT '0'
);
CREATE INDEX ididx ON inv_idx(id);
CREATE INDEX objididx ON inv_idx(objectid);

-- Table structure for table `inv_phrases`
DROP TABLE IF EXISTS inv_phrases;
CREATE TABLE inv_phrases (
  id integer primary key AUTOINCREMENT,
  phrase char(255) DEFAULT ''
);
CREATE INDEX phrase_idx ON inv_phrases(phrase);

-- Table structure for table inv_words
DROP TABLE IF EXISTS inv_words;
CREATE TABLE inv_words (
  id integer primary key AUTOINCREMENT,
  word char(128) DEFAULT ''
);
CREATE INDEX word_idx ON inv_words(word);

-- Table structure for table links
DROP TABLE IF EXISTS links;
CREATE TABLE links (
  fromid int(11) NOT NULL DEFAULT '0',
  toid int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (fromid,toid)
);

-- Table structure for table object
DROP TABLE IF EXISTS object;
CREATE TABLE object (
  objectid integer primary key AUTOINCREMENT,
  url varchar(2000) NOT NULL DEFAULT '',
  domain varchar(50) NOT NULL DEFAULT '0',
  modified timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- TODO: Rethink this trigger, as well as all of the object table
CREATE TRIGGER ObjectModified
AFTER UPDATE ON object
BEGIN
 UPDATE object SET modified = CURRENT_TIMESTAMP WHERE objectid = old.objectid;
END;

-- Table structure for table ontology
DROP TABLE IF EXISTS ontology;
CREATE TABLE ontology (
  child varchar(100) DEFAULT NULL,
  parent varchar(100) DEFAULT NULL,
  weight int(11) DEFAULT NULL,
  PRIMARY KEY (child, parent, weight)
);
