#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h> 

/* -----------------------------------------------------------------------------
   Step 1
   Set the UTI types the importer supports
  
   Modify the CFBundleDocumentTypes entry in Info.plist to contain
   an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes 
   that your importer can handle
   
   -- Tom Dec 15 2008 - Added com.openmeta.openmetaschema to the document types in info.plist
  
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 2 
   Implement the GetMetadataForFile function
  
   Implement the GetMetadataForFile function below to scrape the relevant
   metadata from your document and return it as a CFDictionary using standard keys
   (defined in MDItem.h) whenever possible.
   
   -- Tom Dec 15 2008 - See comments in this GetMetadataForFile. 
   
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 3 (optional) 
   If you have defined new attributes, update the schema.xml file
  
   Edit the schema.xml file to include the metadata keys that your importer returns.
   Add them to the <allattrs> and <displayattrs> elements.
  
   Add any custom types that your importer requires to the <attributes> element
  
   <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>
  
   ----------------------------------------------------------------------------- */



/* -----------------------------------------------------------------------------
    Get metadata attributes from file
   
   This function's job is to extract useful information your file format supports
   and return it as a dictionary
   ----------------------------------------------------------------------------- */

Boolean GetMetadataForFile(void* thisInterface, 
			   CFMutableDictionaryRef attributes, 
			   CFStringRef contentTypeUTI,
			   CFStringRef pathToFile)
{
	/* Pull any available metadata from the file at the specified path */
    /* Return the attribute keys and attribute values in the dict */
    /* Return TRUE if successful, FALSE if there was no data provided */
    
	// the idea is that we want have the importer run on our file type - "com.ironic.openmetaschema"
	// With only one   ".openmetaschema" file on the computer for each app that uses OpenMeta
	// Each app that uses OpenMeta will need to tell Spotlight what keys it uses. This seems espcially important on 10.6 
	// On 10.6 I have found that Spotlight only activates keys that are on the system, (at least the developer prerelease)
	// What this does is make the Spotlight metadata engine look at the 
	// open meta schema file, and generate entries in the user interface and file system where appropriate.
	
	// The end result is that we allow users to search for "tag:foobar" in the spotlight top right (leopard - snow leopard) 
	// spotlight search area, and only search for files with a kOMUserTags of foobar.
	
	// The file should be a dictionary: Each key in the file will be a kOM*, and will have a value that is a representative 
	// value (eg array of strings, or cfnumber, etc)
	CFDictionaryRef fileDict = NULL;
	
	CFURLRef fileURL = CFURLCreateWithFileSystemPath(NULL, pathToFile,kCFURLPOSIXPathStyle , false);
	if (fileURL)
	{
		CFReadStreamRef stream = CFReadStreamCreateWithFile(kCFAllocatorDefault, fileURL);
		if (stream)
		{
			CFPropertyListFormat propertyListFormat = 0;
			CFReadStreamOpen(stream);
			fileDict = CFPropertyListCreateFromStream(NULL, stream, 0,  kCFPropertyListImmutable, &propertyListFormat, nil);
			CFReadStreamClose(stream);
			CFRelease(stream);
		}
		CFRelease(fileURL);
	}
	
	if (fileDict == NULL)
		return FALSE;
	
	if (CFGetTypeID(fileDict) != CFDictionaryGetTypeID())
		return FALSE;
	
	// ok - go through the keys:
	long numItems = CFDictionaryGetCount(fileDict);
	CFStringRef* keys = malloc(sizeof(CFStringRef)*numItems);
	CFTypeRef* values = malloc(sizeof(CFTypeRef)*numItems);
	
	if (numItems == 0 || keys == NULL || values == NULL)
	{
		CFRelease(fileDict);
		return FALSE;
	}
	
	CFShow(fileDict);
	
	CFDictionaryGetKeysAndValues(fileDict, (const void**) keys, (const void**) values);
	long count;
	for (count = 0; count < numItems; count++)
	{
		CFStringRef aKey = keys[count];
		CFTypeRef aValue = values[count];
		CFDictionarySetValue(attributes, aKey, aValue); // set the values
	}
	
	free(keys);
	free(values);
	CFRelease(fileDict);
	
	return TRUE;
}
