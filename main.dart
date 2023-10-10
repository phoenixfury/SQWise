// 1- Imports
import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:soar_quest/soar_quest.dart';

// 2- Global Variables
late final SQCollection items;

// 3- Intialization (main function)
void main() async {
  // 3.1 App Intialized with title SQWise
  await SQApp.init('SQWise');

  // 3.2 Definition of users collection with their respective fields
  final users = LocalCollection(id: 'Users', fields: [
    SQStringField('Username'),
    SQDoubleField('Cost Share')..defaultValue = 0.0,
    SQBoolField('Did Pay')..defaultValue = false,
    SQDoubleField('Total Paid')
      ..show = DocCond((doc, screen) => doc.getValue<bool>('Did Pay') == true),
  ]);

  // 3.3 Definition of items collection with their repective fields and the
  // onDocSaveCallback is triggered when the items save button is pressed
  items = LocalCollection(id: 'Items', fields: [
    SQStringField('Item Name'),
    SQDoubleField('Price'),
    SQListField(SQRefField('Users', collection: users)),
  ])
    ..onDocSaveCallback = (itemDoc) {
      // loop for users
      for (final userDoc in users.docs) {
        // noUserItems list: is the list of items that have no users selected
        // (will be split evenly among all users)
        final noUserItems = items.docs.where(
            (item) => (item.getValue<List<SQRef?>>('Users') ?? []).isEmpty);

        // list for the shared cost of each item
        // sharedCost = sharedItemAmongAllUsers/allUsers
        final noUserItemsCosts = noUserItems
            .map((item) =>
                (item.getValue<double>('Price') ?? 0) / (users.docs.length))
            .toList();

        // items that include only specific number of users chosen from the app for specific item
        // (will not be shared among all users, only users included)
        final itemsDocs = items.docs.where((item) =>
            (item.getValue<List<SQRef?>>('Users') ?? []).contains(userDoc.ref));

        // The shared cost of the items that include specific number of user
        // sharedCost = SharedItem/numberOfUsersSharingThisItem
        final itemsCosts = itemsDocs
            .map((item) =>
                (item.getValue<double>('Price') ?? 0) /
                ((item.getValue('Users') as List?)?.length ?? 1))
            .toList();

        // Simple algorithm to specifiy who should pay money and
        // who should recieve money
        // (recieving money will be at least on of the users that have
        // DidPay=True and can be more than one)
        var totalCosts = 0.0;

        for (final itemCost in itemsCosts) {
          totalCosts += itemCost;
        }
        for (final itemCost in noUserItemsCosts) {
          totalCosts += itemCost;
        }

        userDoc.setValue('Cost Share',
            (userDoc.getValue<double>('Total Paid') ?? 0) - totalCosts);
        users.saveDoc(userDoc);
      }
    };

  // 3.4 Lodaing for items and users collection
  await items.loadCollection();
  await users.loadCollection();

  // 3.5 Link Items with Users (when selecting a user for participation in
  // a specific Item, this Item will be shown in the items fieled for the user)
  users.fields.add(SQInverseListRefsField('Items',
      refCollection: () => items, refFieldName: 'Users'));

  // 3.6 Running the application with a WelcomePage
  // and screens for users and items collections.
  SQApp.run([
    WelcomePage('Welcome'),
    CollectionScreen(collection: users)..icon = Icons.person,
    CollectionScreen(collection: items)..icon = Icons.shopping_cart_outlined
  ],
      themeData: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.tealAccent)));
} // end of main

// 4- A simple screen that displays an Image
class WelcomePage extends Screen {
  WelcomePage(super.title);

  @override
  Widget screenBody() {
    return Center(
        child: Image.network(
            'https://icon-library.com/images/money-stack-icon-png/money-stack-icon-png-25.jpg'));
  }
}
