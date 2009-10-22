//
//  headless_main.m
//  CocoaBugs
//
//  Created by Devin Chalmers on 7/29/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ALifeController.h"
#import "ALifePluginLoader.h"
#import "StatisticsController.h"
#import "ALifeRunExporter.h"
#import "ALifeSimulationController.h"

static NSArray *plugins;

typedef enum {
	kBugsCommandRun,
	kBugsCommandPlugins
} BugsCommand;

void printHelpAndDie()
{
	NSMutableArray *usageStrings = [NSMutableArray array];
	
	[usageStrings addObject:@"Usage: HeadlessBugs <command> <options>"];
	[usageStrings addObject:@"Commands: run, plugins"];
	
	NSString *usageString = [usageStrings componentsJoinedByString:@"\n"];
	printf("%s\n", [usageString cStringUsingEncoding:NSASCIIStringEncoding]);
	
	exit(0);
}

void printUsageAndDie(BugsCommand command) {
	switch (command) {
		case kBugsCommandRun:
			printf("Usage: HeadlessBugs run <config filename>   \n");
			printf("                        --output <output directory path>\n");
			printf("                        --steps <number of steps>\n");
			printf("                        [--runs <number of runs>]\n");
			printf("                        [--shuffle <shuffle key>\n");
			printf("                           [--min <minimum value]\n");
			printf("                           [--max <maximum value] ]\n");
			break;
		default:
			break;
	}
	
	exit(1);
}

void printPluginsAndDie()
{
	NSSortDescriptor *titleSort = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES];
	printf("\nInstalled plugins:\n");
	NSArray *configuration;
	NSArray *statistics;
	for (Class <ALifeController> plugin in plugins) {
		printf("\n%s\n\n", [[plugin name] cStringUsingEncoding:NSASCIIStringEncoding]);
		// print configuration options
		configuration = [[plugin configurationOptions] sortedArrayUsingDescriptors:[NSArray arrayWithObject:titleSort]];
		printf(" Options:\n");
		for (NSDictionary *option in configuration) {
			if ([[option valueForKey:@"type"] isEqual:@"Bitmap"])
				continue;
			
			printf(" - %s\n   Key: %s, range: ", [[option valueForKey:@"title"] cStringUsingEncoding:NSASCIIStringEncoding],
									 [[option valueForKey:@"name"] cStringUsingEncoding:NSASCIIStringEncoding]);
			
			if ([[option valueForKey:@"type"] isEqual:@"Float"]) {
				printf("[%.1f, %.1f]\n", [[option valueForKey:@"minValue"] floatValue], [[option valueForKey:@"maxValue"] floatValue]);
			}
			
			else if ([[option valueForKey:@"type"] isEqual:@"Integer"]) {
				printf("[%d, %d]\n", [[option valueForKey:@"minValue"] intValue], [[option valueForKey:@"maxValue"] intValue]);
			}
		}
		printf("\n");
		
	}
	printf("\n");
}

void runSimulations(NSString *configurationFile,
					NSString *outputDirectory,
					int numberOfSteps,
					int numberOfRuns,
					NSString *shuffleKey,
					NSNumber *shuffleMin,
					NSNumber *shuffleMax)
{
	NSDictionary *data = [NSDictionary dictionaryWithContentsOfFile:configurationFile];
	
	NSString *identifier = [data objectForKey:@"identifier"];
	NSDictionary *configuration = [data objectForKey:@"configuration"];
	
	Class <ALifeController> selectedPlugin;
	for (Class <ALifeController> plugin in plugins) {
		if ([[plugin name] isEqual:identifier]) {
			selectedPlugin = plugin;
			break;
		}
	}
	
	if (!selectedPlugin) {
		printf("Plugin class '%s' not found. Make sure it's installed.", [identifier cStringUsingEncoding:NSASCIIStringEncoding]);
		exit(1);
	}
	
	int step;
	int run;
	int runFrac = (int)(numberOfSteps / 10.0);
	ALifeSimulationController *simulationController;
	StatisticsController *statisticsController;
	
	for (run = 0; run < numberOfRuns; run++) {
		simulationController = [[ALifeSimulationController alloc] initWithSimulationClass:selectedPlugin
																			configuration:configuration];
		
		statisticsController = [[StatisticsController alloc] init];
		statisticsController.statisticsSize = numberOfSteps;
		[statisticsController setSource:[simulationController.lifeController statisticsCollector]
						  forStatistics:[[simulationController.lifeController properties] objectForKey:@"statistics"]];
		
		printf("Run %d", run + 1);
		fflush(stdout);
		for (step = 0; step < numberOfSteps; step++) {
			if (step % runFrac == 0) {
				printf(".");
				fflush(stdout);
			}
			[simulationController.lifeController update];
		}
		NSString *dir = [NSString stringWithFormat:@"%@/%d", outputDirectory, run + 1];
		[ALifeRunExporter exportSimulation:simulationController withStatistics:statisticsController toDirectory:dir];
		
		[statisticsController release];
		[simulationController release];
		
		printf("\n");
	}
	
	printf("Done.\n");
}

int main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
	
	if (argc < 2) {
		printHelpAndDie();
	}
	
	plugins = [ALifePluginLoader allPlugIns];
	
	NSString *command = [NSString stringWithCString:argv[1] encoding:NSASCIIStringEncoding];
	
	if ([command isEqual:@"run"]) {
		if (argc < 3) {
			printUsageAndDie(kBugsCommandRun);
		}
		NSString *configurationFile = [NSString stringWithCString:argv[2] encoding:NSASCIIStringEncoding];
		NSString *outputDirectory = [args stringForKey:@"-output"];
		int numberOfSteps = [args integerForKey:@"-steps"];
		int numberOfRuns  = [args integerForKey:@"-runs"];
		numberOfRuns = numberOfRuns ? numberOfRuns : 1;
		
		if (!(configurationFile && outputDirectory && numberOfSteps)) {
			printUsageAndDie(kBugsCommandRun);
		}
		
		runSimulations(configurationFile, outputDirectory, numberOfSteps, numberOfRuns, nil, nil, nil);
	}
	else if ([command isEqual:@"plugins"]) {
		printPluginsAndDie();
	}
	
	[pool release];
	return 0;
}
