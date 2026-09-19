import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/pack/pack.dart';
import 'child/day_screen.dart';
import 'child/habits_screen.dart';
import 'child/home_screen.dart';
import 'child/trophy_room_screen.dart';
import 'child/word_books_screen.dart';
import 'parent/gate_screen.dart';
import 'parent/today_screen.dart';
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
