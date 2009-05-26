/*
Copyright (c) 2009 ironic software

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
*/

// openmeta. A simple OpenMeta command line tool for setting and getting tags and ratings on any file. 
// User defined tags: Guidelines
// User defined tags are an array of (hopefully short) strings set on any file that there is write permission on.
// These tags are meant to be 'human readable'. There is no concept of namespace. Control characters are not a good idea. 
// Commas are not needed, and are almost always an input error on the part of the user. This tool strips them out. 
// The tags are case preserving but case insensitive. Users don't expect the two tags 'Foo' and 'foo' to be declared on the same file. 
// 

// The overall intent of OpenMeta is to make Mac OS X and spotlight into part of a document managment system that uses open standards on metadata.


// Ratings: Ratings are stored as a floating point number 0.001 to 5.0 - ratings of 0 do not exist. 
// An item with a truly lousy rating should be rated to some small number, like 0.1. The rules for dealing with ratings of '0' vs 
// no rating set on an item are complicated at best. Users don't often think that way.

// The OpenMeta system is capable of storing almost any kind of data about a file, with Spotlight indexing working on 
// that data 'which makes sense' to index in the Spotlight database. Please see the comments in OpenMeta.h and OpenMeta.m for more information.
// openmeta should be updated in the future to set / get many more types of metadata

// Time Machine note: When you set open meta data info (xattrs) on a file, Time Machine will not automatically back up the changed xattrs -
// TimeMachine will only do that if the entire file has a new modification date. One way to do this is to bump the modification date of a 
// file by one second when important meta data is set. touching a file to change the mod date to 'now' may not be the best idea.
// openmeta does not currently change the modification dates on any files on purpose. 

// OpenMeta uses a spotlight importer to tell the Sporlight meta data system what various 
// metadata names mean. For example with OpenMeta you can search for 'tag:foo' or rated:>4 in the 
// OS X upper right global search command. To get this to work, we need to  
// 1) have a plugin in this tool (or someplace else) that tells spotlight and 
// 2) make one file that spotlight will index, so that the plugin will register, etc.
// Perhaps there is a way to do this with a command line tool, but I could not figure that out, as openmeta is not a package
// So to get the UI goodness of being able to type tag:foo into the Spotlight search area you need to run Tagger (free from ironic) at least once,
// leaving tagger or some other packaged UI application on your hard drive. 



#import <Foundation/Foundation.h>
#import "OpenMeta.h"
#import "OpenMetaBackup.h"
#import "OpenMetaPrefs.h"

BOOL gShowErrors = YES;

static NSArray* GetArgs(int argc, const char *argv[]) 
{
  NSMutableArray* args = [NSMutableArray array];
  for (int i = 1; i < argc; i++) 
  {
    NSString* anArg = [NSString stringWithUTF8String:argv[i]];
	if ([anArg length] > 0)
		[args addObject:anArg];
  }
  return args;
}

static void PrintLine(NSString* line)
{
	fprintf(stdout, "%s", [line UTF8String]);
	fprintf(stdout, "\n");
}


static void ReportIfError(NSError* inError)
{
	if (!gShowErrors)
		return;
		
	if (inError == nil)
		return;
	
	PrintLine([inError description]);
}


static BOOL IsCommand(NSString* inString)
{
	if ([inString isEqualToString:@"-p"])
		return YES;
	if ([inString isEqualToString:@"-t"])
		return YES;
	if ([inString isEqualToString:@"-a"])
		return YES;
	if ([inString isEqualToString:@"-s"])
		return YES;
	if ([inString isEqualToString:@"-r"])
		return YES;
	if ([inString isEqualToString:@"-v"])
		return YES;

	return NO;
}

// Read parameters until we hit a command switch
static NSArray* ReadParameters(NSArray* inArgs, int* ioIndex, BOOL stripCommas)
{
	NSMutableArray* parameters = [NSMutableArray array];
	for ( ; *ioIndex < [inArgs count]; (*ioIndex)++)
	{
		NSString* paramOrCommand = [inArgs objectAtIndex:*ioIndex];
		if (IsCommand(paramOrCommand))
			return parameters;
		
		// The use of commas to delimit tags is not good. So we trap them out here.
		if (stripCommas)
		{
			if ([paramOrCommand hasSuffix:@","])
				paramOrCommand = [paramOrCommand substringToIndex:[paramOrCommand length] - 1];
		
			if ([paramOrCommand rangeOfString:@","].location != NSNotFound)
			{
				// if the person has passed in a string like 'foo,bar' then they likely want two tags set, 
				// but this looks like one argument, so split this kind of thing up here:
				NSArray* seperatedArgs = [paramOrCommand componentsSeparatedByString:@","];
				for (NSString* aTag in seperatedArgs)
				{
					if ([aTag length] > 0)
						[parameters addObject:aTag];
				}
				paramOrCommand = @"";
			}
		}
		if ([paramOrCommand length] > 0)
			[parameters addObject:paramOrCommand];
	}
	return parameters;
}

static void SetRating(NSString* inRating, NSString* inPath)
{
	NSError* error = nil;
	if ([inRating length] == 0)
	{
		// if there is no rating passed, it really means to just print the rating:
		double rating = [OpenMeta getRating:inPath error:&error];
		PrintLine([NSString stringWithFormat:@"%f", rating]);
	}
	else
	{
		double rating = [inRating doubleValue];
		if (rating <= 0.0)
			rating = 0.0;
		if (rating > 5.0)
			rating = 5.0;
		if (isnan(rating))
			rating = 0.0;
		
		error = [OpenMeta setRating:rating path:inPath];
	}
	ReportIfError(error);
}

static void AddTags(NSArray* inTags, NSString* inPath)
{
	// get the old tags for the prefs:
	NSArray* existingTags = [OpenMeta getUserTags:inPath error:nil];
	
	NSError* error = [OpenMeta addUserTags:inTags path:inPath];
	
	// update the tags in the prefs.
	[OpenMetaPrefs updatePrefsRecentTags:existingTags newTags:inTags];
	
	ReportIfError(error);
}

static void SetTags(NSArray* inTags, NSString* inPath)
{
	// get the old tags for the prefs:
	NSArray* existingTags = [OpenMeta getUserTags:inPath error:nil];
	NSError* error = [OpenMeta setUserTags:inTags path:inPath];
	
	// update the tags in the prefs.
	[OpenMetaPrefs updatePrefsRecentTags:existingTags newTags:inTags];
	
	ReportIfError(error);
}

static NSString* TagsAsString(NSString* inPath)
{
	NSString* tagString = @"";
	NSError* error = nil;
	NSArray* theTags = [OpenMeta getUserTags:inPath error:&error];
	ReportIfError(error);
	
	BOOL firstOne = YES;
	for (NSString* aTag in theTags)
	{
		if (!firstOne)
			tagString = [tagString stringByAppendingString:@" "];
		firstOne = NO;
		
		if ([aTag rangeOfString:@" "].location != NSNotFound)
		{
			aTag = [@"\"" stringByAppendingString:aTag];
			aTag = [aTag stringByAppendingString:@"\""];
		}
		
		tagString = [tagString stringByAppendingString:aTag];
	}
	return tagString;
}


static void PrintSingleLine(BOOL inListRating, BOOL inListTags, NSString* inPath)
{
	NSError* error = nil;
	double rating = 0.0;
	if (inListRating)
		rating = [OpenMeta getRating:inPath error:&error];
	
	NSString* tagString = @"";
	if (inListTags)
		tagString = TagsAsString(inPath);
	
	if (rating > 0.0)
		PrintLine([NSString stringWithFormat:@"%f %@ %@", rating, tagString, inPath]);
	else
		PrintLine([NSString stringWithFormat:@"%@ %@", tagString, inPath]);
	
	ReportIfError(error);
}

static void PrintInfo(NSString* inPath)
{
	NSError* error = nil;
	PrintLine([NSString stringWithFormat:@"%@", inPath]);
	
	NSString* tagString = TagsAsString(inPath);
	PrintLine([NSString stringWithFormat:@"tags: %@", tagString]);
	
	double rating = [OpenMeta getRating:inPath error:&error];
	if (rating > 0.0)
		PrintLine([NSString stringWithFormat:@"rating: %f", rating]);
	else
		PrintLine([NSString stringWithFormat:@"rating: none found"]);
	
	PrintLine(@"");
	ReportIfError(error);
}


int main (int argc, const char * argv[]) 
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	if (argc < 2) 
	{
		const char *usage =
		"openmeta version 0.1 by Tom Andersen code.google.com/p/openmeta/ \n\n"
		"Usage: openmeta [options] -p PATH[s] \n\n"
		"Note that commas are to be used nowhere - tag lists use quotes for two word tags in output\n\n"
		"example (list tags and ratings):  openmeta -p PATH\n"
		"example (list tags and ratings multiple):  openmeta -p PATH PATH\n"
		"example (list tags): openmeta -t -p PATH[s]\n"
		"example (add tags): openmeta -a foo bar -p PATH[s]\n"
		"example (add tags with spaces): openmeta -a \"three word tag\" \"foo bar\" -p PATH[s]\n"
		"example (set tags):  openmeta -s foo bar -p PATH[s]\n"
		"example (clear all tags):  openmeta -s -p PATH[s]\n"
		"example (set rating 0 - 5 stars):  openmeta -r 3.5 -p PATH[s]\n"
		"example (print rating):  openmeta -r -p PATH[s]\n"
		"example (clear rating):  openmeta -r 0.0 -p PATH[s]\n"
		"example (lousy rating):  openmeta -r 0.1 -p PATH[s]\n";
		"example (to suppress output add -v):  openmeta -v ... \n";
		fprintf(stderr, "%s", usage);
		[pool drain];
		exit(1);
	}
  
	NSArray* theArgs = GetArgs(argc, argv);
	NSArray* thePaths = nil;
	NSArray* addTags = nil;
	NSArray* setTags = nil;
	NSArray* setRatings = nil;
	BOOL printTags = NO;
	BOOL printInfo = YES;
	BOOL verbose = YES;
	
	
	// the first arg is our path:
	int argCount = 0;
	while (argCount < [theArgs count])
	{
		NSString* anArg = [theArgs objectAtIndex:argCount];
		
		argCount++;
		
		if ([anArg isEqualToString:@"-p"])
			thePaths = ReadParameters(theArgs, &argCount, NO);
		else if ([anArg isEqualToString:@"-t"])
			printTags = YES;
		else if ([anArg isEqualToString:@"-a"])
			addTags = ReadParameters(theArgs, &argCount, YES);
		else if ([anArg isEqualToString:@"-s"])
			setTags = ReadParameters(theArgs, &argCount, YES);
		else if ([anArg isEqualToString:@"-r"])
			setRatings = ReadParameters(theArgs, &argCount, YES);
		else if ([anArg isEqualToString:@"-v"])
			verbose = NO;
	}
	
	if (addTags || setTags || setRatings || printTags)
		printInfo = NO;
	
	if (!verbose)
		gShowErrors = NO; // is this the right thing to do?
	
	if (printInfo)
		verbose = NO; 
	
	if ([thePaths count] == 0)
	{
		PrintLine(@"openmeta - no paths found! - use '-p' in front of paths");
		[pool drain];
		exit(1);
	}
	
	BOOL ratingsCommandFound = NO;
	if (setRatings)
		ratingsCommandFound = YES;
	
	for (NSString* aPath in thePaths)
	{
		if (setRatings)
			SetRating([setRatings lastObject], aPath);
		
		if (addTags)
			AddTags(addTags, aPath);
		
		if (setTags)
			SetTags(setTags, aPath);
		
		if (verbose)
			PrintSingleLine(ratingsCommandFound, (addTags || setTags || printTags), aPath);
		
		if (printInfo)
			PrintInfo(aPath);
	}
	[OpenMetaPrefs synchPrefs];
	
	// we need to sleep while the backup thread does its job...
	[OpenMetaBackup appIsTerminating];
	
    [pool drain];
    return 0;
}
