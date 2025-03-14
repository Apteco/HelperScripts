

SELECT a.[id]
	, a.[lastupdate]
	--, a.[addresshash_source]
	--, a.[addresshash_osm]
	--, a.[payload]
	,JSON_VALUE(a.payload, N'$.Count') as counter
, Format(o.lon,'N6','de-de') as longitude
, Format(o.lat,'N6','de-de') as latitude
	, o.*
	, coalesce(town, city, village, suburb, city_district) AS ort
	, CONCAT (
		[road]
		, CASE 
			WHEN [house_number] IS NULL
				THEN ''
			ELSE ' '
			END
		, [house_number]
		, ', '
		, [postcode]
		, ' '
		, coalesce(town, city, village, suburb, city_district)
		) AS AddressString
FROM [server].[database].[tblAddressGeocoded] a
CROSS APPLY openjson(a.payload, N'$.value[0]') WITH (
		licence NVARCHAR(200)
		, lat DECIMAL(10, 6)
		, lon DECIMAL(10, 6)
		, category NVARCHAR(50)
		, type NVARCHAR(50)
		, extratags NVARCHAR(max) N'$.extratags' AS JSON
		, address_string VARCHAR(400)
		, road NVARCHAR(50) N'$.address.road'
		, house_number NVARCHAR(50) N'$.address.house_number'
		, neighbourhood NVARCHAR(50) N'$.address.neighbourhood'
		, suburb NVARCHAR(50) N'$.address.suburb'
		, city_district NVARCHAR(50) N'$.address.city_district'
		, city NVARCHAR(50) N'$.address.city'
		, village NVARCHAR(50) N'$.address.village'
		, town NVARCHAR(50) N'$.address.town'
		, county NVARCHAR(50) N'$.address.county'
		, STATE NVARCHAR(50) N'$.address.state'
		, postcode NVARCHAR(10) N'$.address.postcode'
		, country NVARCHAR(50) N'$.address.country'
		, country_code NVARCHAR(2) N'$.address.country_code'
		--, count int N'$.Count'
		) AS o
--where a.payload is not null and JSON_VALUE(a.payload, N'$.Count') > 1