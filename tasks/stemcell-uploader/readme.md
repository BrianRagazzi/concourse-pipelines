# Stemcell-uploader

## Status: Works

## Notes
Lots of tweaks in this one; you may optionally pass the PRODUCT_IDENTIFIER value

First, it checks the metadata for a stemcell dependency, if one is not found there,
it queries stemcell_assignments in the opsmgr API.  If a PRODUCT_IDENTIFIER value is passed, it'll search for the required stemcell version for that product.  
If the PRODIUCT_IDENTIFER is not passed, it'll find any staged products where the deployed stemcell version is null.
If none of that produces a stemcell version, it'll give up
