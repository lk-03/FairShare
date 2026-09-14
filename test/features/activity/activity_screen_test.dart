import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/comment.dart';
import 'package:fairshare/core/models/expense.dart';
import 'package:fairshare/core/models/expense_shortcut.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/core/models/split.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/data/providers/expenses_provider.dart';
import 'package:fairshare/data/providers/groups_provider.dart';
import 'package:fairshare/features/activity/presentation/screens/activity_screen.dart';
import 'package:fairshare/features/expenses/presentation/widgets/transaction_comments_section.dart';

void main() {
  late SharedPreferences prefs;
  late LocalCacheService cacheService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheService = LocalCacheService(prefs);
  });

  final testUser = UserProfile(
    id: 'user_1',
    email: 'alex@fairshare.app',
    fullName: 'Alex Vance',
    createdAt: DateTime(2026, 1, 1),
  );

  final testMemberSam = GroupMember(
    id: 'gm_2',
    cohortId: 'cohort_1',
    userId: 'user_sam',
    role: 'member',
    joinedAt: DateTime(2026, 1, 1),
    profile: UserProfile(
      id: 'user_sam',
      fullName: 'Sam Altman',
      username: 'sama',
      email: 'sam@fairshare.app',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  final testMemberAlex = GroupMember(
    id: 'gm_1',
    cohortId: 'cohort_1',
    userId: 'user_1',
    role: 'admin',
    joinedAt: DateTime(2026, 1, 1),
    profile: testUser,
  );

  final testGroup = Group(
    id: 'cohort_1',
    name: 'Flat 402 - Bangalore',
    description: 'Roommate split expenses',
    category: 'house',
    currency: 'INR',
    createdBy: 'user_1',
    inviteCode: 'FLAT402',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    members: [testMemberAlex, testMemberSam],
  );

  final testExpense1 = Expense(
    id: 'exp_1',
    cohortId: 'cohort_1',
    title: 'Weekly Groceries & Supplies',
    category: 'groceries',
    totalAmount: 1200.0,
    paidByUserId: 'user_1',
    paidByName: 'Alex Vance',
    splitType: SplitType.equal,
    splits: const [
      ExpenseSplit(userId: 'user_1', amount: 600.0),
      ExpenseSplit(userId: 'user_sam', amount: 600.0),
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
  );

  final testExpense2 = Expense(
    id: 'exp_2',
    cohortId: 'cohort_1',
    title: 'Dinner at Toit',
    category: 'dining',
    totalAmount: 2500.0,
    paidByUserId: 'user_sam',
    paidByName: 'Sam Altman',
    splitType: SplitType.equal,
    splits: const [
      ExpenseSplit(userId: 'user_1', amount: 1250.0),
      ExpenseSplit(userId: 'user_sam', amount: 1250.0),
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
  );

  final testComment1 = TransactionComment(
    id: 'comm_1',
    expenseId: 'exp_1',
    cohortId: 'cohort_1',
    userId: 'user_1',
    content: 'Paid via UPI, please check @sama',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    profile: testUser,
  );

  Widget buildTestScope({
    required Widget child,
    List<Expense>? expenses,
    List<TransactionComment>? comments,
    Function(ExpenseShortcut)? onAddShortcut,
    Function(String)? onAddComment,
  }) {
    final expList = expenses ?? [testExpense1, testExpense2];
    final commList = comments ?? [testComment1];

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localCacheServiceProvider.overrideWithValue(cacheService),
        currentUserProvider.overrideWith(() => _MockCurrentUser(testUser)),
        groupsProvider.overrideWith(() => _MockGroupsNotifier([testGroup])),
        groupExpensesProvider('cohort_1')
            .overrideWith(() => _MockExpensesNotifier('cohort_1', expList)),
        expenseCommentsProvider('exp_1')
            .overrideWith(() => _MockCommentsNotifier('exp_1', commList, onAdd: onAddComment)),
        expenseCommentsProvider('exp_2')
            .overrideWith(() => _MockCommentsNotifier('exp_2', [])),
        expenseShortcutsProvider('cohort_1')
            .overrideWith(() => _MockShortcutsNotifier('cohort_1', onAdd: onAddShortcut)),
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('ActivityScreen renders feed with expenses and comments', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestScope(child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Global Ledger Audit & Expense Timeline'), findsOneWidget);

    // Verify Search Bar & Pills
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search activity, groups, or comments...'), findsOneWidget);
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('Expenses (2)'), findsOneWidget);
    expect(find.text('Comments (1)'), findsOneWidget);
    expect(find.text('RECENT TIMELINE'), findsOneWidget);

    // Verify Expense Items
    expect(find.text('Weekly Groceries & Supplies'), findsNWidgets(2)); // Once for expense, once for comment
    expect(find.text('Dinner at Toit'), findsOneWidget);

    // Verify Comment Item
    expect(find.text('You commented: "Paid via UPI, please check @sama" • Flat 402 - Bangalore'), findsOneWidget);
  });

  testWidgets('ActivityScreen filters by status pill (Expenses vs Comments)', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestScope(child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    // Tap Expenses
    await tester.tap(find.text('Expenses (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Weekly Groceries & Supplies'), findsOneWidget);
    expect(find.text('Dinner at Toit'), findsOneWidget);
    expect(find.textContaining('You commented:'), findsNothing);

    // Tap Comments
    await tester.tap(find.text('Comments (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Weekly Groceries & Supplies'), findsOneWidget); // title of the commented expense
    expect(find.text('Dinner at Toit'), findsNothing);
    expect(find.textContaining('You commented:'), findsOneWidget);

    // Tap All
    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();

    expect(find.text('Dinner at Toit'), findsOneWidget);
  });

  testWidgets('ActivityScreen filters dynamically via search query', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestScope(child: const ActivityScreen()),
    );
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'Toit');
    await tester.pumpAndSettle();

    expect(find.text('Dinner at Toit'), findsOneWidget);
    expect(find.textContaining('Groceries'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Weekly Groceries & Supplies'), findsNWidgets(2));
    expect(find.text('Dinner at Toit'), findsOneWidget);
  });

  testWidgets('ActivityScreen long-press on expense opens action modal and saves shortcut', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ExpenseShortcut? savedShortcut;

    await tester.pumpWidget(
      buildTestScope(
        child: const ActivityScreen(),
        onAddShortcut: (s) => savedShortcut = s,
      ),
    );
    await tester.pumpAndSettle();

    // Long press on Dinner at Toit expense
    await tester.longPress(find.text('Dinner at Toit'));
    await tester.pumpAndSettle();

    // Verify modal options
    expect(find.text('Save as Shortcut'), findsOneWidget);
    expect(find.text('Go to Group'), findsOneWidget);

    // Tap Save as Shortcut
    await tester.tap(find.text('Save as Shortcut'));
    await tester.pumpAndSettle();

    expect(savedShortcut, isNotNull);
    expect(savedShortcut!.title, 'Dinner at Toit');
    expect(savedShortcut!.amount, 2500.0);
    expect(savedShortcut!.splitType, 'equal');
  });

  testWidgets('TransactionCommentsSection renders comments, highlights @mentions, and submits new comment', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? submittedText;

    await tester.pumpWidget(
      buildTestScope(
        child: const SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: TransactionCommentsSection(
              expenseId: 'exp_1',
              cohortId: 'cohort_1',
            ),
          ),
        ),
        onAddComment: (txt) => submittedText = txt,
      ),
    );
    await tester.pumpAndSettle();

    // Verify Header & Live Audit badge
    expect(find.text('DISCUSSION & NOTES (1)'), findsOneWidget);
    expect(find.text('Live Audit'), findsOneWidget);

    // Verify existing comment & mention
    expect(find.text('You'), findsOneWidget);
    expect(find.byType(RichText), findsWidgets);

    // Enter @ to trigger mention suggestions
    final inputField = find.byType(TextField);
    await tester.enterText(inputField, 'Hey @');
    await tester.pumpAndSettle();

    expect(find.text('@all'), findsOneWidget);
    expect(find.text('@Sam Altman'), findsOneWidget);

    // Tap @all chip
    await tester.tap(find.text('@all'));
    await tester.pumpAndSettle();

    expect(find.text('Hey @all '), findsOneWidget);

    // Submit comment
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(submittedText, 'Hey @all');
  });
}

class _MockCurrentUser extends CurrentUserNotifier {
  final UserProfile _user;
  _MockCurrentUser(this._user);

  @override
  UserProfile? build() => _user;
}

class _MockGroupsNotifier extends GroupsNotifier {
  final List<Group> _groups;
  _MockGroupsNotifier(this._groups);

  @override
  AsyncValue<List<Group>> build() => AsyncValue.data(_groups);

  @override
  Future<void> loadUserGroups() async {}
}

class _MockExpensesNotifier extends GroupExpensesNotifier {
  final List<Expense> _expenses;
  _MockExpensesNotifier(super.cohortId, this._expenses);

  @override
  AsyncValue<List<Expense>> build() => AsyncValue.data(_expenses);

  @override
  Future<void> loadExpenses() async {}
}

class _MockCommentsNotifier extends ExpenseCommentsNotifier {
  final List<TransactionComment> _initial;
  final Function(String)? onAdd;

  _MockCommentsNotifier(super.expenseId, this._initial, {this.onAdd});

  @override
  AsyncValue<List<TransactionComment>> build() => AsyncValue.data(_initial);

  @override
  Future<void> loadComments() async {}

  @override
  Future<TransactionComment> addComment(String content) async {
    onAdd?.call(content);
    final newComm = TransactionComment(
      id: 'comm_${DateTime.now().millisecondsSinceEpoch}',
      expenseId: 'exp_1',
      userId: 'user_1',
      content: content,
      createdAt: DateTime.now(),
    );
    final current = state.value ?? [];
    state = AsyncValue.data([...current, newComm]);
    return newComm;
  }
}

class _MockShortcutsNotifier extends ExpenseShortcutsNotifier {
  final Function(ExpenseShortcut)? onAdd;

  _MockShortcutsNotifier(super.cohortId, {this.onAdd});

  @override
  AsyncValue<List<ExpenseShortcut>> build() => const AsyncValue.data([]);

  @override
  Future<void> loadShortcuts() async {}

  @override
  Future<ExpenseShortcut> addShortcut(ExpenseShortcut shortcut) async {
    onAdd?.call(shortcut);
    return shortcut;
  }
}
