

IF EXISTS (SELECT 1 FROM [PeopleStage].[tblAddressGeocoded] WHERE [id] = '#ID#')
    BEGIN
        UPDATE [PeopleStage].[tblAddressGeocoded]
        SET [id] = #ID#                     --<id, int,>
          ,[succeeded] = #SUCCESS#          --<succeeded, bit,>
          ,[addresshash_source] = @srcHash --<addresshash_source, varbinary(max),>
          ,[addresshash_osm] = @osmHash    --<addresshash_osm, varbinary(max),>
          ,[payload] = #PAYLOAD#            --<payload, varchar(max),>
        WHERE [id] = '#ID#';
    END
ELSE
    BEGIN
        INSERT INTO [PeopleStage].[tblAddressGeocoded]
                    ([id]
                    ,[succeeded]
                    ,[addresshash_source]
                    ,[addresshash_osm]
                    ,[payload])
                VALUES
                    (
                    #ID#        --<id, int,>
                    ,#SUCCESS#  --<succeeded, bit,>
                    ,@srcHash  --<addresshash_source, varbinary(max),>
                    ,@osmHash  --<addresshash_osm, varbinary(max),>
                    ,#PAYLOAD#  --<payload, varchar(max),>
                    );
    END