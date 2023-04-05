

SELECT *
FROM (
	SELECT *
		, HASHBYTES('SHA2_256', [AddressString]) AS AddressHash
	FROM (
		SELECT --TOP (10)
			[Id]
			, [Strasse]
			, [Hausnummer]
			, [Zusatz1]
			, [Zusatz2]
			, [PLZ]
			, [Ort]
			, [Land]
			, CONCAT (
				[Strasse]
				, ' '
				, [Hausnummer]
				, ', '
				, [PLZ]
				, ' '
				, [Ort]
				) AS AddressString
			, CONCAT (
				Strasse
				, ' '
				, Hausnummer
				) AS Strasse2
		FROM [server].[database].[tblAddress]
		WHERE Land in ('DE','NL')
		) a
	) b
WHERE b.AddressHash NOT IN (
		SELECT [addresshash_source]
		FROM [server].[PeopleStage].[tblAddressGeocoded] t
		WHERE t.id = b.id
			AND t.addresshash_source = b.AddressHash
		)
	OR b.Id NOT IN (
		SELECT [Id]
		FROM [server].[PeopleStage].[tblAddressGeocoded] t
		WHERE t.id = b.id
		)

/*
-- Not tested yet, but also add always addresses that have lower quality
OR b.Id IN (
		SELECT TOP 300 [Id]
		FROM [server].[database].[tblAddressGeocoded] t
		WHERE (
				JSON_VALUE(payload, N'$.value[0].category') = 'highway'
				OR JSON_VALUE(payload, N'$.Count') > 5
		)
		--and datediff(day, lastupdate,GETDATE()) > 90
				--and t.id = b.id
		ORDER BY newid()
		
		)
		*/