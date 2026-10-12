import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/pack/pack.dart';
import 'child/day_screen.dart';
import 'child/habits_screen.dart';
import 'child/home_screen.dart';
import 'child/sticker_book_screen.dart';
import 'child/stories_screen.dart';
import 'child/trophy_room_screen.dart';
import 'child/word_books_screen.dart';
import 'parent/backup_screen.dart';
import 'parent/child_screen.dart';
import 'parent/credits_screen.dart';
import 'parent/gate_screen.dart';
import 'parent/packs_screen.dart';
import 'parent/settings_screen.dart';
import 'parent/today_screen.dart';
import 'parent/week_screen.dart';
import 'theme/motion.dart';

part 'router.g.dart';

/// Built once and never rebuilt, so it watches nothing.
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          _fade(context, state, const HomeScreen()),
      routes: [
        GoRoute(
          path: 'day/:weekday',
          pageBuilder: (context, state) => _fade(
            context,
            state,
            DayScreen(Weekday.values.byName(state.pathParameters['weekday']!)),
          ),
        ),
        GoRoute(
          path: 'trophies',
          pageBuilder: (context, state) =>
              _fade(context, state, const TrophyRoomScreen()),
          routes: [
            GoRoute(
              path: 'stickers',
              pageBuilder: (context, state) =>
                  _fade(context, state, const StickerBookScreen()),
            ),
          ],
        ),
        GoRoute(
          path: 'stickers',
          pageBuilder: (context, state) =>
              _fade(context, state, const StickerBookScreen()),
        ),
        GoRoute(
          path: 'words',
          pageBuilder: (context, state) =>
              _fade(context, state, const WordBooksScreen()),
          routes: [
            GoRoute(
              path: ':pack/:book',
              pageBuilder: (context, state) => _fade(
                context,
                state,
                WordCardScreen(
                  state.pathParameters['pack']!,
                  state.pathParameters['book']!,
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'stories',
          pageBuilder: (context, state) =>
              _fade(context, state, const StoriesScreen()),
          routes: [
            GoRoute(
              path: ':pack/:story',
              pageBuilder: (context, state) => _fade(
                context,
                state,
                StoryReaderScreen(
                  state.pathParameters['pack']!,
                  state.pathParameters['story']!,
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'habits',
          pageBuilder: (context, state) =>
              _fade(context, state, const HabitsScreen()),
        ),
        GoRoute(
          path: 'gate',
          pageBuilder: (context, state) =>
              _fade(context, state, const GateScreen()),
        ),
        GoRoute(
          path: 'parent',
          pageBuilder: (context, state) =>
              _fade(context, state, const ParentTodayScreen()),
          routes: [
            GoRoute(
              path: 'packs',
              pageBuilder: (context, state) =>
                  _fade(context, state, const PacksScreen()),
            ),
            GoRoute(
              path: 'week',
              pageBuilder: (context, state) =>
                  _fade(context, state, const WeekScreen()),
            ),
            GoRoute(
              path: 'child',
              pageBuilder: (context, state) =>
                  _fade(context, state, const ChildScreen()),
            ),
            GoRoute(
              path: 'backup',
              pageBuilder: (context, state) =>
                  _fade(context, state, const BackupScreen()),
            ),
            GoRoute(
              path: 'settings',
              pageBuilder: (context, state) =>
                  _fade(context, state, const SettingsScreen()),
            ),
            GoRoute(
              path: 'credits',
              pageBuilder: (context, state) =>
                  _fade(context, state, const CreditsScreen()),
            ),
          ],
        ),
      ],
    ),
  ],
);

Page<void> _fade(BuildContext context, GoRouterState state, Widget child) {
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Motion.long;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: animation.drive(CurveTween(curve: Motion.curve)),
          child: child,
        ),
  );
}
