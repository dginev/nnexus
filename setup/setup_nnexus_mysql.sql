-- How to create a NNexus database and User in MySQL:
-- execute with " mysql -u root -p < setup_nnexus_mysql.sql "
create database nnexus;
grant usage on *.* to nnexus@localhost identified by 'nnexus-password-here';
grant all privileges on nnexus.* to nnexus@localhost;