DROP TABLE IF EXISTS Sessions;
CREATE TABLE Sessions(
	start     TEXT NOT NULL,
	stop      TEXT NOT NULL,
	rfid      INTEGER NOT NULL,
	omtale    INTEGER NOT NULL,
	flere     INTEGER NOT NULL,
	relaterte INTEGER NOT NULL,
	PRIMARY KEY(start, stop));

DROP TABLE IF EXISTS Omtaler;
CREATE TABLE Omtaler(
	time   TEXT NOT NULL PRIMARY KEY,
	uri    TEXT NOT NULL,
	author TEXT NOT NULL,
	title  TEXT NOT NULL,
	antall INTEGER NOT NULL);
