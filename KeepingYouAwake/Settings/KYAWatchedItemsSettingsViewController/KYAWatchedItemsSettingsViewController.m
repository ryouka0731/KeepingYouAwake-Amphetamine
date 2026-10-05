//
//  KYAWatchedItemsSettingsViewController.m
//  KeepingYouAwake
//
//  Created for issue #40 — Watched Items settings pane.
//

#import "KYAWatchedItemsSettingsViewController.h"
#import <KYACommon/KYACommon.h>
#import <KYAApplicationSupport/KYAApplicationSupport.h>
#import "KYALocalizedStrings.h"

#if __has_include(<UniformTypeIdentifiers/UniformTypeIdentifiers.h>)
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#endif

typedef NS_ENUM(NSInteger, KYAWatchedItemsListKind) {
    KYAWatchedItemsListKindWiFiSSIDs = 0,
    KYAWatchedItemsListKindApplications,
    KYAWatchedItemsListKindDownloadDirectories,
    KYAWatchedItemsListKindScheduleWindows,
};

/// Minutes in one day; valid minute-of-day values are 0..(this - 1).
static const NSInteger KYAMinutesPerDay = 24 * 60;

/// Reuse identifier for the schedule-section row stack view.
static NSString * const KYAScheduleWindowRowIdentifier = @"KYAScheduleWindowRowView";

@interface KYAWatchedItemsSettingsViewController ()
@property (nonatomic) NSTableView *ssidTableView;
@property (nonatomic) NSTableView *applicationsTableView;
@property (nonatomic) NSTableView *directoriesTableView;
@property (nonatomic) NSTableView *scheduleTableView;

@property (nonatomic) NSSegmentedControl *ssidControl;
@property (nonatomic) NSSegmentedControl *applicationsControl;
@property (nonatomic) NSSegmentedControl *directoriesControl;
@property (nonatomic) NSSegmentedControl *scheduleControl;

@property (nonatomic) NSMutableArray<NSString *> *ssids;
@property (nonatomic) NSMutableArray<NSString *> *bundleIdentifiers;
@property (nonatomic) NSMutableArray<NSString *> *directories;

/// Each entry is a mutable copy of a `kya_scheduleWindows` dictionary:
/// keys `KYAScheduleWindowKeyWeekdays` (NSArray<NSNumber*> of 1..7),
/// `KYAScheduleWindowKeyStartMinutes` and `KYAScheduleWindowKeyEndMinutes`
/// (NSNumber, 0..1439).
@property (nonatomic) NSMutableArray<NSMutableDictionary<NSString *, id> *> *scheduleWindows;
@end

@implementation KYAWatchedItemsSettingsViewController

+ (NSImage *)tabViewItemImage
{
    if(@available(macOS 11.0, *))
    {
        return [NSImage imageWithSystemSymbolName:@"eye" accessibilityDescription:nil];
    }
    else
    {
        return [NSImage imageNamed:NSImageNameListViewTemplate];
    }
}

+ (NSString *)preferredTitle
{
    return KYA_SETTINGS_L10N_WATCHED_ITEMS;
}

- (BOOL)resizesView
{
    // The view is built programmatically and is taller than the settings
    // window's default content size, so let the base class size the tab
    // view to our fittingSize.
    return YES;
}

#pragma mark - Life Cycle

- (instancetype)init
{
    // The base KYASettingsContentViewController -init is the designated
    // initializer; it sets nibName to the class name but since we override
    // -loadView the Nib is never loaded, so this is safe.
    self = [super init];
    if(self)
    {
        self.title = [[self class] preferredTitle];
    }
    return self;
}

- (void)loadView
{
    [self loadModel];

    Auto rootView = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 480.0, 460.0)];

    Auto stackView = [NSStackView new];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    stackView.alignment = NSLayoutAttributeLeading;
    stackView.distribution = NSStackViewDistributionFill;
    stackView.spacing = 16.0;
    stackView.edgeInsets = NSEdgeInsetsMake(16.0, 20.0, 16.0, 20.0);
    [rootView addSubview:stackView];

    [NSLayoutConstraint activateConstraints:@[
        // Pin the stack view to every edge so the root view derives its
        // fittingSize (~480 x ~460) from the stack view's content.
        [stackView.topAnchor constraintEqualToAnchor:rootView.topAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:rootView.bottomAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor],
    ]];

    NSTableView *ssidTableView = nil;
    NSSegmentedControl *ssidControl = nil;
    [stackView addArrangedSubview:[self sectionViewWithTitle:KYA_L10N_WATCHED_WIFI_SSIDS
                                                        hint:KYA_L10N_WATCHED_WIFI_SSIDS_HINT
                                                    editable:YES
                                                   tableView:&ssidTableView
                                                     control:&ssidControl
                                                        kind:KYAWatchedItemsListKindWiFiSSIDs]];
    self.ssidTableView = ssidTableView;
    self.ssidControl = ssidControl;

    NSTableView *applicationsTableView = nil;
    NSSegmentedControl *applicationsControl = nil;
    [stackView addArrangedSubview:[self sectionViewWithTitle:KYA_L10N_WATCHED_APPLICATIONS
                                                        hint:KYA_L10N_WATCHED_APPLICATIONS_HINT
                                                    editable:NO
                                                   tableView:&applicationsTableView
                                                     control:&applicationsControl
                                                        kind:KYAWatchedItemsListKindApplications]];
    self.applicationsTableView = applicationsTableView;
    self.applicationsControl = applicationsControl;

    NSTableView *directoriesTableView = nil;
    NSSegmentedControl *directoriesControl = nil;
    [stackView addArrangedSubview:[self sectionViewWithTitle:KYA_L10N_WATCHED_DOWNLOAD_DIRECTORIES
                                                        hint:KYA_L10N_WATCHED_DOWNLOAD_DIRECTORIES_HINT
                                                    editable:NO
                                                   tableView:&directoriesTableView
                                                     control:&directoriesControl
                                                        kind:KYAWatchedItemsListKindDownloadDirectories]];
    self.directoriesTableView = directoriesTableView;
    self.directoriesControl = directoriesControl;

    NSTableView *scheduleTableView = nil;
    NSSegmentedControl *scheduleControl = nil;
    [stackView addArrangedSubview:[self scheduleSectionViewWithTableView:&scheduleTableView
                                                                control:&scheduleControl]];
    self.scheduleTableView = scheduleTableView;
    self.scheduleControl = scheduleControl;

    self.view = rootView;

    [self updateRemoveButtonsEnabledState];
}

#pragma mark - Section Builder

- (NSView *)sectionViewWithTitle:(NSString *)title
                            hint:(NSString *)hint
                        editable:(BOOL)editable
                       tableView:(NSTableView * _Nullable __autoreleasing * _Nonnull)outTableView
                         control:(NSSegmentedControl * _Nullable __autoreleasing * _Nonnull)outControl
                            kind:(KYAWatchedItemsListKind)kind
{
    Auto section = [NSStackView new];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.orientation = NSUserInterfaceLayoutOrientationVertical;
    section.alignment = NSLayoutAttributeLeading;
    section.spacing = 6.0;

    Auto titleLabel = [NSTextField labelWithString:title];
    titleLabel.font = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
    [section addArrangedSubview:titleLabel];

    Auto hintLabel = [NSTextField wrappingLabelWithString:hint];
    hintLabel.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    hintLabel.textColor = NSColor.secondaryLabelColor;
    // Pin the wrapping label to the section width so its intrinsic height
    // is deterministic (otherwise fittingSize can be wrong/collapsed).
    hintLabel.preferredMaxLayoutWidth = 440.0;
    [section addArrangedSubview:hintLabel];
    [hintLabel.widthAnchor constraintEqualToConstant:440.0].active = YES;

    // Table view inside a scroll view.
    Auto tableView = [NSTableView new];
    tableView.headerView = nil;
    tableView.usesAlternatingRowBackgroundColors = YES;
    tableView.allowsMultipleSelection = NO;
    tableView.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.tag = kind;

    Auto column = [[NSTableColumn alloc] initWithIdentifier:@"value"];
    column.editable = editable;
    column.resizingMask = NSTableColumnAutoresizingMask;
    [tableView addTableColumn:column];
    tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;

    Auto scrollView = [NSScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;
    scrollView.documentView = tableView;
    [section addArrangedSubview:scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.heightAnchor constraintEqualToConstant:96.0],
        [scrollView.widthAnchor constraintEqualToConstant:440.0],
    ]];

    // Add / Remove segmented control.
    Auto control = [NSSegmentedControl new];
    control.translatesAutoresizingMaskIntoConstraints = NO;
    control.segmentStyle = NSSegmentStyleSmallSquare;
    control.trackingMode = NSSegmentSwitchTrackingMomentary;
    control.segmentCount = 2;
    if(@available(macOS 11.0, *))
    {
        [control setImage:[NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:NSLocalizedString(@"Add", @"Add")] forSegment:0];
        [control setImage:[NSImage imageWithSystemSymbolName:@"minus" accessibilityDescription:NSLocalizedString(@"Remove", @"Remove")] forSegment:1];
    }
    else
    {
        [control setImage:[NSImage imageNamed:NSImageNameAddTemplate] forSegment:0];
        [control setImage:[NSImage imageNamed:NSImageNameRemoveTemplate] forSegment:1];
    }
    [control setWidth:28.0 forSegment:0];
    [control setWidth:28.0 forSegment:1];
    control.target = self;
    control.action = @selector(segmentedControlAction:);
    control.tag = kind;
    [section addArrangedSubview:control];

    *outTableView = tableView;
    *outControl = control;
    return section;
}

/// Builds the "Active Hours" section: a view-based table whose rows each
/// represent one schedule window (weekday picker + start/end time pickers)
/// plus a +/- segmented control. Mirrors the layout of the cell-based
/// sections above but with richer per-row controls.
- (NSView *)scheduleSectionViewWithTableView:(NSTableView * _Nullable __autoreleasing * _Nonnull)outTableView
                                     control:(NSSegmentedControl * _Nullable __autoreleasing * _Nonnull)outControl
{
    Auto section = [NSStackView new];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.orientation = NSUserInterfaceLayoutOrientationVertical;
    section.alignment = NSLayoutAttributeLeading;
    section.spacing = 6.0;

    Auto titleLabel = [NSTextField labelWithString:KYA_L10N_SCHEDULE_WINDOWS];
    titleLabel.font = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
    [section addArrangedSubview:titleLabel];

    Auto hintLabel = [NSTextField wrappingLabelWithString:KYA_L10N_SCHEDULE_WINDOWS_HINT];
    hintLabel.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    hintLabel.textColor = NSColor.secondaryLabelColor;
    hintLabel.preferredMaxLayoutWidth = 440.0;
    [section addArrangedSubview:hintLabel];
    [hintLabel.widthAnchor constraintEqualToConstant:440.0].active = YES;

    Auto tableView = [NSTableView new];
    tableView.headerView = nil;
    tableView.usesAlternatingRowBackgroundColors = YES;
    tableView.allowsMultipleSelection = NO;
    tableView.rowSizeStyle = NSTableViewRowSizeStyleCustom;
    tableView.rowHeight = 32.0;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.tag = KYAWatchedItemsListKindScheduleWindows;

    Auto column = [[NSTableColumn alloc] initWithIdentifier:@"window"];
    column.editable = NO;
    column.resizingMask = NSTableColumnAutoresizingMask;
    [tableView addTableColumn:column];
    tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;

    Auto scrollView = [NSScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;
    scrollView.documentView = tableView;
    [section addArrangedSubview:scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.heightAnchor constraintEqualToConstant:120.0],
        [scrollView.widthAnchor constraintEqualToConstant:440.0],
    ]];

    Auto control = [NSSegmentedControl new];
    control.translatesAutoresizingMaskIntoConstraints = NO;
    control.segmentStyle = NSSegmentStyleSmallSquare;
    control.trackingMode = NSSegmentSwitchTrackingMomentary;
    control.segmentCount = 2;
    if(@available(macOS 11.0, *))
    {
        [control setImage:[NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:NSLocalizedString(@"Add", @"Add")] forSegment:0];
        [control setImage:[NSImage imageWithSystemSymbolName:@"minus" accessibilityDescription:NSLocalizedString(@"Remove", @"Remove")] forSegment:1];
    }
    else
    {
        [control setImage:[NSImage imageNamed:NSImageNameAddTemplate] forSegment:0];
        [control setImage:[NSImage imageNamed:NSImageNameRemoveTemplate] forSegment:1];
    }
    [control setWidth:28.0 forSegment:0];
    [control setWidth:28.0 forSegment:1];
    control.target = self;
    control.action = @selector(segmentedControlAction:);
    control.tag = KYAWatchedItemsListKindScheduleWindows;
    [section addArrangedSubview:control];

    *outTableView = tableView;
    *outControl = control;
    return section;
}

#pragma mark - Model

- (void)loadModel
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    self.ssids = [[defaults kya_watchedWiFiSSIDs] mutableCopy] ?: [NSMutableArray new];
    self.bundleIdentifiers = [[defaults kya_watchedApplicationBundleIdentifiers] mutableCopy] ?: [NSMutableArray new];
    self.directories = [[defaults kya_downloadDirectories] mutableCopy] ?: [NSMutableArray new];

    Auto windows = [NSMutableArray new];
    for(id entry in (defaults.kya_scheduleWindows ?: @[]))
    {
        if(![entry isKindOfClass:[NSDictionary class]]) { continue; }
        [windows addObject:[self normalizedScheduleWindowFromDictionary:(NSDictionary *)entry]];
    }
    self.scheduleWindows = windows;
}

/// Coerces an arbitrary persisted dictionary into a clean mutable window
/// dictionary with all three keys present and clamped to valid ranges.
- (NSMutableDictionary<NSString *, id> *)normalizedScheduleWindowFromDictionary:(NSDictionary *)dictionary
{
    Auto weekdays = [NSMutableArray new];
    Auto seen = [NSMutableSet new];
    for(id day in [dictionary[KYAScheduleWindowKeyWeekdays] isKindOfClass:[NSArray class]] ? dictionary[KYAScheduleWindowKeyWeekdays] : @[])
    {
        if(![day isKindOfClass:[NSNumber class]]) { continue; }
        NSInteger value = ((NSNumber *)day).integerValue;
        if(value < 1 || value > 7) { continue; }
        Auto boxed = @(value);
        if([seen containsObject:boxed]) { continue; }
        [seen addObject:boxed];
        [weekdays addObject:boxed];
    }
    [weekdays sortUsingSelector:@selector(compare:)];

    NSInteger start = [dictionary[KYAScheduleWindowKeyStartMinutes] isKindOfClass:[NSNumber class]]
        ? ((NSNumber *)dictionary[KYAScheduleWindowKeyStartMinutes]).integerValue : 9 * 60;
    NSInteger end = [dictionary[KYAScheduleWindowKeyEndMinutes] isKindOfClass:[NSNumber class]]
        ? ((NSNumber *)dictionary[KYAScheduleWindowKeyEndMinutes]).integerValue : 18 * 60;
    start = MAX((NSInteger)0, MIN(KYAMinutesPerDay - 1, start));
    end = MAX((NSInteger)0, MIN(KYAMinutesPerDay - 1, end));

    return [@{
        KYAScheduleWindowKeyWeekdays: weekdays,
        KYAScheduleWindowKeyStartMinutes: @(start),
        KYAScheduleWindowKeyEndMinutes: @(end),
    } mutableCopy];
}

- (NSMutableArray<NSString *> *)modelForKind:(KYAWatchedItemsListKind)kind
{
    switch(kind)
    {
        case KYAWatchedItemsListKindWiFiSSIDs: return self.ssids;
        case KYAWatchedItemsListKindApplications: return self.bundleIdentifiers;
        case KYAWatchedItemsListKindDownloadDirectories: return self.directories;
        case KYAWatchedItemsListKindScheduleWindows: break; // not a string list; handled separately
    }
    return [NSMutableArray new];
}

- (NSTableView *)tableViewForKind:(KYAWatchedItemsListKind)kind
{
    switch(kind)
    {
        case KYAWatchedItemsListKindWiFiSSIDs: return self.ssidTableView;
        case KYAWatchedItemsListKindApplications: return self.applicationsTableView;
        case KYAWatchedItemsListKindDownloadDirectories: return self.directoriesTableView;
        case KYAWatchedItemsListKindScheduleWindows: return self.scheduleTableView;
    }
    return nil;
}

- (void)persistModelForKind:(KYAWatchedItemsListKind)kind
{
    Auto defaults = NSUserDefaults.standardUserDefaults;
    switch(kind)
    {
        case KYAWatchedItemsListKindWiFiSSIDs:
        {
            // Never persist an in-progress placeholder row.
            NSArray<NSString *> *ssids = [self.ssids filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
            defaults.kya_watchedWiFiSSIDs = (ssids.count > 0) ? ssids : nil;
        }
            break;
        case KYAWatchedItemsListKindApplications:
            defaults.kya_watchedApplicationBundleIdentifiers = (self.bundleIdentifiers.count > 0) ? [self.bundleIdentifiers copy] : nil;
            break;
        case KYAWatchedItemsListKindDownloadDirectories:
            defaults.kya_downloadDirectories = (self.directories.count > 0) ? [self.directories copy] : nil;
            break;
        case KYAWatchedItemsListKindScheduleWindows:
            [self persistScheduleWindows];
            break;
    }
}

/// Writes the whole `scheduleWindows` model back to user defaults as an
/// immutable array of immutable dictionaries (or nil when empty).
- (void)persistScheduleWindows
{
    if(self.scheduleWindows.count == 0)
    {
        NSUserDefaults.standardUserDefaults.kya_scheduleWindows = nil;
        return;
    }
    Auto out = [NSMutableArray new];
    for(NSDictionary *window in self.scheduleWindows)
    {
        [out addObject:[window copy]];
    }
    NSUserDefaults.standardUserDefaults.kya_scheduleWindows = [out copy];
}

/// Inserts `string` (trimmed) into the given list unless it is empty or a
/// case-insensitive duplicate. Returns YES if inserted.
- (BOOL)addString:(NSString *)string toKind:(KYAWatchedItemsListKind)kind
{
    Auto trimmed = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(trimmed.length == 0) { return NO; }

    Auto model = [self modelForKind:kind];
    for(NSString *existing in model)
    {
        if([existing caseInsensitiveCompare:trimmed] == NSOrderedSame) { return NO; }
    }
    [model addObject:trimmed];
    [self persistModelForKind:kind];
    [[self tableViewForKind:kind] reloadData];
    [self updateRemoveButtonsEnabledState];
    return YES;
}

#pragma mark - Actions

- (void)segmentedControlAction:(NSSegmentedControl *)sender
{
    Auto kind = (KYAWatchedItemsListKind)sender.tag;
    if(sender.selectedSegment == 0)
    {
        [self addItemForKind:kind];
    }
    else
    {
        [self removeSelectedItemForKind:kind];
    }
}

- (void)addItemForKind:(KYAWatchedItemsListKind)kind
{
    switch(kind)
    {
        case KYAWatchedItemsListKindWiFiSSIDs:
            [self addEmptySSIDRowAndBeginEditing];
            break;
        case KYAWatchedItemsListKindApplications:
            [self presentApplicationOpenPanel];
            break;
        case KYAWatchedItemsListKindDownloadDirectories:
            [self presentDirectoryOpenPanel];
            break;
        case KYAWatchedItemsListKindScheduleWindows:
            [self addDefaultScheduleWindow];
            break;
    }
}

- (void)addDefaultScheduleWindow
{
    // A sensible default: weekdays Monday–Friday (NSCalendar 2..6),
    // 09:00 to 18:00.
    Auto window = [@{
        KYAScheduleWindowKeyWeekdays: @[ @2, @3, @4, @5, @6 ],
        KYAScheduleWindowKeyStartMinutes: @(9 * 60),
        KYAScheduleWindowKeyEndMinutes: @(18 * 60),
    } mutableCopy];
    [self.scheduleWindows addObject:window];
    [self persistScheduleWindows];
    [self.scheduleTableView reloadData];
    Auto row = (NSInteger)(self.scheduleWindows.count - 1);
    [self.scheduleTableView scrollRowToVisible:row];
    [self.scheduleTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];
    [self updateRemoveButtonsEnabledState];
}

- (void)addEmptySSIDRowAndBeginEditing
{
    // Append a placeholder row and immediately begin editing it. The value
    // is committed (trimmed / deduped / dropped-if-empty) when the cell-based
    // table calls -tableView:setObjectValue:forTableColumn:row: on edit end.
    // Escape aborts editing without that call, so drop any placeholder an
    // earlier add left behind first.
    [self removeEmptySSIDPlaceholders];
    [self.ssids addObject:@""];
    [self.ssidTableView reloadData];
    Auto row = (NSInteger)(self.ssids.count - 1);
    [self.ssidTableView scrollRowToVisible:row];
    [self.ssidTableView editColumn:0 row:row withEvent:nil select:YES];
    [self updateRemoveButtonsEnabledState];
}

/// Removes placeholder rows whose editing was aborted (Escape). They are
/// never persisted, but would otherwise linger as empty rows.
- (void)removeEmptySSIDPlaceholders
{
    NSIndexSet *empty = [self.ssids indexesOfObjectsPassingTest:^BOOL(NSString *ssid, NSUInteger index, BOOL *stop) {
        return ssid.length == 0;
    }];
    if(empty.count == 0) { return; }
    [self.ssids removeObjectsAtIndexes:empty];
    [self.ssidTableView reloadData];
    [self updateRemoveButtonsEnabledState];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    if(notification.object != self.ssidTableView) { return; }
    // Also posted when Escape cancels editing, which commits nothing. Run
    // after the table has applied a committed value, so only a row that
    // is still empty is dropped.
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf removeEmptySSIDPlaceholders];
    });
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];
    // Commit or drop an edit in progress, then clear leftover placeholders.
    [self.view.window makeFirstResponder:nil];
    [self removeEmptySSIDPlaceholders];
}

- (void)removeSelectedItemForKind:(KYAWatchedItemsListKind)kind
{
    Auto tableView = [self tableViewForKind:kind];
    Auto selectedRow = tableView.selectedRow;

    if(kind == KYAWatchedItemsListKindScheduleWindows)
    {
        if(selectedRow < 0 || selectedRow >= (NSInteger)self.scheduleWindows.count) { return; }
        [self.scheduleWindows removeObjectAtIndex:(NSUInteger)selectedRow];
        [self persistScheduleWindows];
        [tableView reloadData];
        [self updateRemoveButtonsEnabledState];
        return;
    }

    Auto model = [self modelForKind:kind];
    if(selectedRow < 0 || selectedRow >= (NSInteger)model.count) { return; }

    [model removeObjectAtIndex:(NSUInteger)selectedRow];
    [self persistModelForKind:kind];
    [tableView reloadData];
    [self updateRemoveButtonsEnabledState];
}

#pragma mark - Open Panels

- (void)presentApplicationOpenPanel
{
    Auto panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.canCreateDirectories = NO;
    panel.prompt = KYA_L10N_WATCHED_ITEMS_CHOOSE_APPLICATION;
    panel.title = KYA_L10N_WATCHED_ITEMS_CHOOSE_APPLICATION;
    panel.treatsFilePackagesAsDirectories = NO;

#if __has_include(<UniformTypeIdentifiers/UniformTypeIdentifiers.h>)
    if(@available(macOS 11.0, *))
    {
        panel.allowedContentTypes = @[ UTTypeApplicationBundle ];
    }
    else
#endif
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        panel.allowedFileTypes = @[ @"app" ];
#pragma clang diagnostic pop
    }

    __weak typeof(self) weakSelf = self;
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if(strongSelf == nil) { return; }
        if(result != NSModalResponseOK) { return; }
        NSURL *url = panel.URL;
        if(url == nil) { return; }

        NSBundle *bundle = [NSBundle bundleWithURL:url];
        NSString *bundleIdentifier = bundle.bundleIdentifier;
        if(bundleIdentifier.length == 0)
        {
            NSBeep();
            Auto alert = [NSAlert new];
            alert.messageText = KYA_L10N_WATCHED_ITEMS_NO_BUNDLE_IDENTIFIER_TITLE;
            alert.informativeText = KYA_L10N_WATCHED_ITEMS_NO_BUNDLE_IDENTIFIER_MESSAGE;
            [alert addButtonWithTitle:KYA_L10N_OK];
            [alert beginSheetModalForWindow:strongSelf.view.window completionHandler:nil];
            return;
        }
        [strongSelf addString:bundleIdentifier toKind:KYAWatchedItemsListKindApplications];
    }];
}

- (void)presentDirectoryOpenPanel
{
    Auto panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    panel.canCreateDirectories = YES;
    panel.prompt = KYA_L10N_WATCHED_ITEMS_CHOOSE_FOLDER;
    panel.title = KYA_L10N_WATCHED_ITEMS_CHOOSE_FOLDER;

    __weak typeof(self) weakSelf = self;
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if(strongSelf == nil) { return; }
        if(result != NSModalResponseOK) { return; }
        NSURL *url = panel.URL;
        if(url == nil) { return; }
        NSString *path = [url.path stringByAbbreviatingWithTildeInPath];
        [strongSelf addString:path toKind:KYAWatchedItemsListKindDownloadDirectories];
    }];
}

#pragma mark - Remove Button State

- (void)updateRemoveButtonsEnabledState
{
    NSSegmentedControl *controls[] = { self.ssidControl, self.applicationsControl, self.directoriesControl, self.scheduleControl };
    for(size_t i = 0; i < sizeof(controls) / sizeof(controls[0]); i++)
    {
        NSSegmentedControl *control = controls[i];
        if(control == nil) { continue; }
        Auto kind = (KYAWatchedItemsListKind)control.tag;
        BOOL hasSelection = ([self tableViewForKind:kind].selectedRow >= 0);
        [control setEnabled:hasSelection forSegment:1];
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if((KYAWatchedItemsListKind)tableView.tag == KYAWatchedItemsListKindScheduleWindows)
    {
        return (NSInteger)self.scheduleWindows.count;
    }
    return (NSInteger)[self modelForKind:(KYAWatchedItemsListKind)tableView.tag].count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    // The schedule table is view-based; it has no string object value.
    if((KYAWatchedItemsListKind)tableView.tag == KYAWatchedItemsListKindScheduleWindows) { return nil; }
    Auto model = [self modelForKind:(KYAWatchedItemsListKind)tableView.tag];
    if(row < 0 || row >= (NSInteger)model.count) { return @""; }
    return model[(NSUInteger)row];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    // Only the SSID column is editable.
    Auto kind = (KYAWatchedItemsListKind)tableView.tag;
    if(kind != KYAWatchedItemsListKindWiFiSSIDs) { return; }

    Auto newValue = [object isKindOfClass:[NSString class]] ? (NSString *)object : @"";
    Auto trimmed = [newValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if(row < 0 || row >= (NSInteger)self.ssids.count) { return; }

    Auto previousValue = self.ssids[(NSUInteger)row];
    BOOL wasPlaceholder = (previousValue.length == 0);

    BOOL isDuplicate = NO;
    for(NSInteger i = 0; i < (NSInteger)self.ssids.count; i++)
    {
        if(i == row) { continue; }
        if([self.ssids[(NSUInteger)i] caseInsensitiveCompare:trimmed] == NSOrderedSame) { isDuplicate = YES; break; }
    }

    if(trimmed.length == 0 || (isDuplicate && wasPlaceholder))
    {
        // Empty input, or a freshly-added placeholder row resolved to a
        // duplicate — discard the row.
        [self.ssids removeObjectAtIndex:(NSUInteger)row];
    }
    else if(isDuplicate)
    {
        // Editing an existing entry into a duplicate of another — keep the
        // previous value, do not destroy the row.
        [tableView reloadData];
        [self updateRemoveButtonsEnabledState];
        return;
    }
    else
    {
        self.ssids[(NSUInteger)row] = trimmed;
    }

    [self persistModelForKind:KYAWatchedItemsListKindWiFiSSIDs];
    [tableView reloadData];
    [self updateRemoveButtonsEnabledState];
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    [self updateRemoveButtonsEnabledState];
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    // Only the schedule table is view-based; the others are cell-based and
    // never reach this method.
    if((KYAWatchedItemsListKind)tableView.tag != KYAWatchedItemsListKindScheduleWindows) { return nil; }
    if(row < 0 || row >= (NSInteger)self.scheduleWindows.count) { return nil; }

    NSStackView *rowStack = (NSStackView *)[tableView makeViewWithIdentifier:KYAScheduleWindowRowIdentifier owner:self];
    NSSegmentedControl *weekdayControl = nil;
    NSDatePicker *startPicker = nil;
    NSDatePicker *endPicker = nil;

    if(rowStack != nil)
    {
        for(NSView *subview in rowStack.arrangedSubviews)
        {
            if([subview.identifier isEqualToString:@"weekdays"]) { weekdayControl = (NSSegmentedControl *)subview; }
            else if([subview.identifier isEqualToString:@"start"]) { startPicker = (NSDatePicker *)subview; }
            else if([subview.identifier isEqualToString:@"end"]) { endPicker = (NSDatePicker *)subview; }
        }
        // Defensive: if a reused row view is missing any of its expected
        // subviews (e.g. someone added an unrelated subview to the stack,
        // or an identifier collision returns an unrelated view), drop the
        // reused container and rebuild from scratch instead of dereferencing
        // a nil control below.
        if(weekdayControl == nil || startPicker == nil || endPicker == nil)
        {
            rowStack = nil;
            weekdayControl = nil;
            startPicker = nil;
            endPicker = nil;
        }
    }

    if(rowStack == nil)
    {
        rowStack = [self makeFreshScheduleRowViewWithWeekdayControl:&weekdayControl
                                                        startPicker:&startPicker
                                                          endPicker:&endPicker];
    }

    Auto window = self.scheduleWindows[(NSUInteger)row];
    Auto weekdays = [window[KYAScheduleWindowKeyWeekdays] isKindOfClass:[NSArray class]] ? window[KYAScheduleWindowKeyWeekdays] : @[];
    for(NSInteger segment = 0; segment < 7; segment++)
    {
        // Segment 0 = Sunday (weekday 1) … segment 6 = Saturday (weekday 7).
        BOOL on = [weekdays containsObject:@(segment + 1)];
        [weekdayControl setSelected:on forSegment:segment];
    }
    NSInteger startMinutes = [window[KYAScheduleWindowKeyStartMinutes] isKindOfClass:[NSNumber class]] ? ((NSNumber *)window[KYAScheduleWindowKeyStartMinutes]).integerValue : 0;
    NSInteger endMinutes = [window[KYAScheduleWindowKeyEndMinutes] isKindOfClass:[NSNumber class]] ? ((NSNumber *)window[KYAScheduleWindowKeyEndMinutes]).integerValue : 0;
    startPicker.dateValue = [self dateForMinutesSinceMidnight:startMinutes];
    endPicker.dateValue = [self dateForMinutesSinceMidnight:endMinutes];

    return rowStack;
}

/// Builds a brand-new schedule-row stack view with its three input
/// controls wired up. Used both for the initial inflation path and as
/// the recovery path when a reused view came back missing a subview.
- (NSStackView *)makeFreshScheduleRowViewWithWeekdayControl:(NSSegmentedControl * _Nullable __autoreleasing * _Nonnull)outWeekday
                                                startPicker:(NSDatePicker * _Nullable __autoreleasing * _Nonnull)outStart
                                                  endPicker:(NSDatePicker * _Nullable __autoreleasing * _Nonnull)outEnd
{
    Auto rowStack = [NSStackView new];
    rowStack.identifier = KYAScheduleWindowRowIdentifier;
    rowStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    rowStack.alignment = NSLayoutAttributeCenterY;
    rowStack.spacing = 6.0;
    rowStack.translatesAutoresizingMaskIntoConstraints = NO;

    Auto weekdayControl = [NSSegmentedControl new];
    weekdayControl.identifier = @"weekdays";
    weekdayControl.segmentStyle = NSSegmentStyleSmallSquare;
    weekdayControl.trackingMode = NSSegmentSwitchTrackingSelectAny;
    weekdayControl.segmentCount = 7;
    weekdayControl.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    Auto symbols = [self sundayFirstShortWeekdaySymbols];
    for(NSInteger i = 0; i < 7; i++)
    {
        [weekdayControl setLabel:symbols[(NSUInteger)i] forSegment:i];
        [weekdayControl setWidth:24.0 forSegment:i];
    }
    weekdayControl.target = self;
    weekdayControl.action = @selector(scheduleWeekdayControlChanged:);
    [rowStack addArrangedSubview:weekdayControl];

    Auto fromLabel = [NSTextField labelWithString:KYA_L10N_SCHEDULE_WINDOWS_FROM];
    fromLabel.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    fromLabel.textColor = NSColor.secondaryLabelColor;
    [rowStack addArrangedSubview:fromLabel];

    Auto startPicker = [self makeTimeDatePickerWithIdentifier:@"start" action:@selector(scheduleStartPickerChanged:)];
    [rowStack addArrangedSubview:startPicker];

    Auto toLabel = [NSTextField labelWithString:KYA_L10N_SCHEDULE_WINDOWS_TO];
    toLabel.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    toLabel.textColor = NSColor.secondaryLabelColor;
    [rowStack addArrangedSubview:toLabel];

    Auto endPicker = [self makeTimeDatePickerWithIdentifier:@"end" action:@selector(scheduleEndPickerChanged:)];
    [rowStack addArrangedSubview:endPicker];

    *outWeekday = weekdayControl;
    *outStart = startPicker;
    *outEnd = endPicker;
    return rowStack;
}

#pragma mark - Schedule Row Helpers

/// The localized short weekday symbols ordered Sunday-first so that index
/// `i` corresponds to NSCalendar weekday number `i + 1`.
- (NSArray<NSString *> *)sundayFirstShortWeekdaySymbols
{
    Auto formatter = [NSDateFormatter new];
    formatter.locale = NSLocale.currentLocale;
    // -veryShortWeekdaySymbols / -shortWeekdaySymbols are always indexed
    // 0 = Sunday … 6 = Saturday regardless of the locale's first weekday.
    Auto symbols = formatter.veryShortWeekdaySymbols ?: formatter.shortWeekdaySymbols;
    if(symbols.count == 7) { return symbols; }
    return @[ @"S", @"M", @"T", @"W", @"T", @"F", @"S" ];
}

/// A UTC gregorian calendar used as the conversion frame between an
/// integer minute-of-day (0..1439) and the NSDate values shown by an
/// NSDatePicker. Using UTC eliminates DST: minute arithmetic on local
/// `startOfDay` is off by an hour on the spring-forward / fall-back day,
/// so a stored 23:50 can round-trip as 00:50 (or vice versa).
+ (NSCalendar *)kya_utcGregorianCalendar
{
    static NSCalendar *calendar = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        calendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    });
    return calendar;
}

- (NSDate *)dateForMinutesSinceMidnight:(NSInteger)minutes
{
    minutes = MAX((NSInteger)0, MIN(KYAMinutesPerDay - 1, minutes));
    Auto components = [NSDateComponents new];
    components.year = 2001;
    components.month = 1;
    components.day = 1;
    components.hour = minutes / 60;
    components.minute = minutes % 60;
    components.second = 0;
    Auto calendar = [[self class] kya_utcGregorianCalendar];
    return [calendar dateFromComponents:components] ?: [NSDate dateWithTimeIntervalSinceReferenceDate:0];
}

- (NSInteger)minutesSinceMidnightForDate:(NSDate *)date
{
    Auto calendar = [[self class] kya_utcGregorianCalendar];
    Auto components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:date];
    NSInteger minutes = components.hour * 60 + components.minute;
    return MAX((NSInteger)0, MIN(KYAMinutesPerDay - 1, minutes));
}

- (NSDatePicker *)makeTimeDatePickerWithIdentifier:(NSString *)identifier action:(SEL)action
{
    Auto picker = [NSDatePicker new];
    picker.identifier = identifier;
    picker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    picker.datePickerElements = NSDatePickerElementFlagHourMinute;
    picker.datePickerMode = NSDatePickerModeSingle;
    picker.bezeled = YES;
    picker.drawsBackground = NO;
    picker.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    // Render and parse in the same UTC calendar/timezone we use for
    // minute-of-day conversion, so the hour the user sees in the picker
    // is exactly the hour we persist (no DST shift on transition days).
    picker.calendar = [[self class] kya_utcGregorianCalendar];
    picker.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    picker.target = self;
    picker.action = action;
    return picker;
}

#pragma mark - Schedule Row Actions

- (void)scheduleWeekdayControlChanged:(NSSegmentedControl *)sender
{
    NSInteger row = [self.scheduleTableView rowForView:sender];
    if(row < 0 || row >= (NSInteger)self.scheduleWindows.count) { return; }

    Auto weekdays = [NSMutableArray new];
    for(NSInteger segment = 0; segment < 7; segment++)
    {
        if([sender isSelectedForSegment:segment]) { [weekdays addObject:@(segment + 1)]; }
    }
    self.scheduleWindows[(NSUInteger)row][KYAScheduleWindowKeyWeekdays] = weekdays;
    [self persistScheduleWindows];
}

- (void)scheduleStartPickerChanged:(NSDatePicker *)sender
{
    NSInteger row = [self.scheduleTableView rowForView:sender];
    if(row < 0 || row >= (NSInteger)self.scheduleWindows.count) { return; }
    self.scheduleWindows[(NSUInteger)row][KYAScheduleWindowKeyStartMinutes] = @([self minutesSinceMidnightForDate:sender.dateValue]);
    [self persistScheduleWindows];
}

- (void)scheduleEndPickerChanged:(NSDatePicker *)sender
{
    NSInteger row = [self.scheduleTableView rowForView:sender];
    if(row < 0 || row >= (NSInteger)self.scheduleWindows.count) { return; }
    self.scheduleWindows[(NSUInteger)row][KYAScheduleWindowKeyEndMinutes] = @([self minutesSinceMidnightForDate:sender.dateValue]);
    [self persistScheduleWindows];
}

@end
