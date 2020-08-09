/*

Instructions copied-and-pasted (and slightly modified) from the original
InstallHax.m:

clang -dynamiclib -fmodules InstallHax.m -o Hax.dylib
codesign -f -s - Hax.dylib

csrutil disable
nvram boot-args='-no_compat_check amfi_get_out_of_my_way=1'

launchctl setenv DYLD_INSERT_LIBRARIES $PWD/Hax.dylib

*/

/* This is based on HaxLib.dylib by ASentientBot, with modifications
 * by Barry K. Nathan (BarryKN).
 */

@import Foundation;
@import ObjectiveC.runtime;

NSString* TRACE_PREFIX=@"Hax3: ";
void trace(NSString* message)
{
	NSLog(@"%@%@",TRACE_PREFIX,message);
}

void swizzle(Class realClass,Class fakeClass,SEL realSelector,SEL fakeSelector,BOOL instance)
{
	Method realMethod;
	Method fakeMethod;
	if(instance)
	{
		realMethod=class_getInstanceMethod(realClass,realSelector);
		fakeMethod=class_getInstanceMethod(fakeClass,fakeSelector);
	}
	else
	{
		realMethod=class_getClassMethod(realClass,realSelector);
		fakeMethod=class_getClassMethod(fakeClass,fakeSelector);
	}
	
	if(!realMethod||!fakeMethod)
	{
		trace(@"swizzle fail");
		return;
	}
	
	method_exchangeImplementations(realMethod,fakeMethod);
	
	trace(@"swizzle complete");
}

@interface FakeFunctions:NSObject
@end
@implementation FakeFunctions
-(BOOL)fakeIsUpdateInstallable:(id)something
{
	trace(@"force compatible");
	return true;
}
#if 0
-(BOOL)fakeHasSufficientSpaceForMSUInstall:(id)thing1 error:(id)thing2
{
	trace(@"force enough space");
	return true;
}
#endif
-(BOOL)fakeDoNotSealSystem
{
	trace(@"force disable seal");
	return true;
}
+(BOOL)fakeAPFSSupportedByROM
{
	trace(@"APFS hack");
	return true;
}
@end

@interface Inject:NSObject
@end
@implementation Inject
+(void)load
{
	trace(@"loaded");
	
	swizzle(NSClassFromString(@"BIBuildInformation"),FakeFunctions.class,@selector(isUpdateInstallable:),@selector(fakeIsUpdateInstallable:),true);
#if 0
	swizzle(NSClassFromString(@"OSISCustomizationController"),FakeFunctions.class,@selector(hasSufficientSpaceForMSUInstall:error:),@selector(fakeHasSufficientSpaceForMSUInstall:error:),true);
#endif
	swizzle(NSClassFromString(@"OSISCustomizationController"),FakeFunctions.class,@selector(doNotSealSystem),@selector(fakeDoNotSealSystem),true);
	swizzle(NSClassFromString(@"OSISUtilities"),FakeFunctions.class,@selector(apfsSupportedByROM),@selector(fakeAPFSSupportedByROM),false);
}
@end
