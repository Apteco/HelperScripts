CREATE TABLE [PeopleStage].[tblAddressGeocoded](
	[id] [int] NULL,
	[lastupdate] [datetime] NULL,
	[succeeded] [bit] NULL,
	[addresshash_source] [varbinary](max) NULL,
	[addresshash_osm] [varbinary](max) NULL,
	[payload] [varchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [PeopleStage].[tblAddressGeocoded] ADD  DEFAULT (getdate()) FOR [lastupdate]
GO