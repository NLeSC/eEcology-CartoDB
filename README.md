# eEcology-CartoDB
Documentation and script to setup a CartoDB server with eEcology tables

Setup cartodb machine see [setup.md](setup.md)

# Create tables

The `gps.ee_*_limited` views from db.e-ecology.sara.nl have been converted in cartodb tables in `gps_limited.cartodb.ddl.sql`.
Tables can be created with:

    # Retrieve organization database name
    # Create gps schema in organization database
    # Create tables in gps schema

# Export tables

Uses postgresql copy command to dump data from the `gps.ee_*_limited` views at db.e-ecology.sara.nl

# Import tables

Import data using postgresql copy command

# Grant access

The CartoDB organization must have select rights on the e-ecology tables. 
