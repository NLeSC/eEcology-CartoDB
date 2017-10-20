# eEcology-CartoDB
Documentation and script to setup a CartoDB server with eEcology tables

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.1033929.svg)](https://doi.org/10.5281/zenodo.1033929)

Setup cartodb machine see [setup.md](setup.md)

# Create tables

The `gps.ee_*_limited` views from db.e-ecology.sara.nl have been converted in cartodb tables in `gps_limited.cartodb.ddl.sql`.
Tables can be created with:

    # Retrieve organization database name
    ORGANIZATION_DB=`echo "SELECT database_name FROM users u JOIN organizations o ON u.id=o.owner_id WHERE o.name='ee'" | sudo -u postgres psql -t carto_db_production`
    # Create gps schema in organization database
    # Create tables in gps schema
    # Grant organization select rights on tables
    psql -U postgres $ORGANIZATION_DB < gps_limited.cartodb.ddl.sql

# Export tables

Uses postgresql copy command to dump data from the `gps.ee_*_limited` views at db.e-ecology.sara.nl

    psql -U someone -h db.e-ecology.sara.nl eecology < export.psql

# Import tables

Import data using postgresql copy command

    psql -U cartodb $ORGANIZATION_DB < import.psql
