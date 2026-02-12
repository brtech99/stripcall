import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screenshot_wrapper.dart';

// Import the screens we want to screenshot
import 'package:stripcall/pages/auth/login_page.dart';
import 'package:stripcall/widgets/adaptive/adaptive.dart';
import 'package:stripcall/theme/theme.dart';

void main() {
  group('Golden Screenshots - Light Mode', () {
    group('Material (Android)', () {
      testWidgets('Login Page', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.material(child: const LoginPage()),
        );
        await tester.pump();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/material_light/login_page.png'),
        );
      });

      testWidgets('AppButton variants', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.material(
            child: Scaffold(
              body: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      onPressed: () {},
                      child: const Text('Primary Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton.secondary(
                      onPressed: () {},
                      child: const Text('Secondary Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton(
                      onPressed: () {},
                      isLoading: true,
                      child: const Text('Loading Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton(
                      onPressed: null,
                      child: const Text('Disabled Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton(
                      onPressed: () {},
                      isDestructive: true,
                      child: const Text('Destructive Button'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/material_light/button_variants.png'),
        );
      });

      testWidgets('AppTextField variants', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.material(
            child: Scaffold(
              body: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppTextField(
                      label: 'Email',
                      hint: 'Enter your email',
                      controller: TextEditingController(),
                    ),
                    AppSpacing.verticalMd,
                    AppTextField(
                      label: 'Password',
                      hint: 'Enter your password',
                      obscureText: true,
                      controller: TextEditingController(),
                    ),
                    AppSpacing.verticalMd,
                    AppTextField(
                      label: 'With Error',
                      errorText: 'This field is required',
                      controller: TextEditingController(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/material_light/textfield_variants.png'),
        );
      });

      testWidgets('AppCard and AppListTile', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.material(
            child: Scaffold(
              body: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  children: [
                    AppCard(
                      child: Column(
                        children: [
                          AppListTile(
                            leading: const Icon(Icons.event),
                            title: const Text('Event Name'),
                            subtitle: const Text('January 15, 2026'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {},
                          ),
                          AppListTile(
                            leading: const Icon(Icons.people),
                            title: const Text('Crew Members'),
                            subtitle: const Text('5 members'),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.verticalMd,
                    const AppEmptyState(
                      icon: Icons.inbox,
                      title: 'No items found',
                      subtitle: 'There are no items to display',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/material_light/card_listtile.png'),
        );
      });

      testWidgets('Loading states', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.material(
            child: const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppLoadingIndicator(),
                    AppSpacing.verticalLg,
                    Text('Loading...'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(); // Don't settle - we want to see the spinner

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/material_light/loading_indicator.png'),
        );
      });
    });

    group('Cupertino (iOS)', () {
      testWidgets('Login Page', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.cupertino(child: const LoginPage()),
        );
        await tester.pump();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cupertino_light/login_page.png'),
        );
      });

      testWidgets('AppButton variants', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.cupertino(
            child: Scaffold(
              body: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      onPressed: () {},
                      child: const Text('Primary Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton.secondary(
                      onPressed: () {},
                      child: const Text('Secondary Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton(
                      onPressed: () {},
                      isLoading: true,
                      child: const Text('Loading Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton(
                      onPressed: null,
                      child: const Text('Disabled Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton(
                      onPressed: () {},
                      isDestructive: true,
                      child: const Text('Destructive Button'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cupertino_light/button_variants.png'),
        );
      });

      testWidgets('AppTextField variants', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.cupertino(
            child: Scaffold(
              body: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppTextField(
                      label: 'Email',
                      hint: 'Enter your email',
                      controller: TextEditingController(),
                    ),
                    AppSpacing.verticalMd,
                    AppTextField(
                      label: 'Password',
                      hint: 'Enter your password',
                      obscureText: true,
                      controller: TextEditingController(),
                    ),
                    AppSpacing.verticalMd,
                    AppTextField(
                      label: 'With Error',
                      errorText: 'This field is required',
                      controller: TextEditingController(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cupertino_light/textfield_variants.png'),
        );
      });

      testWidgets('AppCard and AppListTile', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.cupertino(
            child: Scaffold(
              body: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  children: [
                    AppCard(
                      child: Column(
                        children: [
                          AppListTile(
                            leading: const Icon(Icons.event),
                            title: const Text('Event Name'),
                            subtitle: const Text('January 15, 2026'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {},
                          ),
                          AppListTile(
                            leading: const Icon(Icons.people),
                            title: const Text('Crew Members'),
                            subtitle: const Text('5 members'),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.verticalMd,
                    const AppEmptyState(
                      icon: Icons.inbox,
                      title: 'No items found',
                      subtitle: 'There are no items to display',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cupertino_light/card_listtile.png'),
        );
      });

      testWidgets('Loading states', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.cupertino(
            child: const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppLoadingIndicator(),
                    AppSpacing.verticalLg,
                    Text('Loading...'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(); // Don't settle - we want to see the spinner

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cupertino_light/loading_indicator.png'),
        );
      });
    });
  });

  group('Golden Screenshots - Dark Mode', () {
    group('Material (Android)', () {
      testWidgets('AppButton variants', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.material(
            isDarkMode: true,
            child: Scaffold(
              body: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      onPressed: () {},
                      child: const Text('Primary Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton.secondary(
                      onPressed: () {},
                      child: const Text('Secondary Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton(
                      onPressed: () {},
                      isDestructive: true,
                      child: const Text('Destructive Button'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/material_dark/button_variants.png'),
        );
      });
    });

    group('Cupertino (iOS)', () {
      testWidgets('AppButton variants', (tester) async {
        await tester.pumpWidget(
          ScreenshotWrapper.cupertino(
            isDarkMode: true,
            child: Scaffold(
              body: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      onPressed: () {},
                      child: const Text('Primary Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton.secondary(
                      onPressed: () {},
                      child: const Text('Secondary Button'),
                    ),
                    AppSpacing.verticalMd,
                    AppButton(
                      onPressed: () {},
                      isDestructive: true,
                      child: const Text('Destructive Button'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cupertino_dark/button_variants.png'),
        );
      });
    });
  });
}
