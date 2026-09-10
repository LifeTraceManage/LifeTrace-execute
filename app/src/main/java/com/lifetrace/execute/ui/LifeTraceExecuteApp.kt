package com.lifetrace.execute.ui

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.lifetrace.execute.ui.screens.CalendarScreen
import com.lifetrace.execute.ui.screens.CloudConnectionScreen
import com.lifetrace.execute.ui.screens.CollectionScreen
import com.lifetrace.execute.ui.screens.ProfileScreen
import com.lifetrace.execute.ui.screens.ProjectsScreen
import com.lifetrace.execute.ui.screens.ReviewScreen
import com.lifetrace.execute.ui.screens.TasksRoute
import com.lifetrace.execute.ui.screens.TodayScreen
import com.lifetrace.execute.ui.theme.LifeBlue
import com.lifetrace.execute.ui.theme.LifeBlueSoft
import com.lifetrace.execute.ui.theme.LifeMuted
import com.lifetrace.execute.ui.theme.LifeSurface

private data class Destination(
    val route: String,
    val label: String,
    val icon: ImageVector
)

private val topLevelDestinations = listOf(
    Destination("today", "今天", Icons.Filled.Home),
    Destination("tasks", "任务", Icons.Outlined.CheckCircle),
    Destination("projects", "项目", Icons.Outlined.Folder),
    Destination("calendar", "日历", Icons.Outlined.CalendarMonth),
    Destination("collection", "收集", Icons.Outlined.Inbox),
)

@Composable
fun LifeTraceExecuteApp() {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route ?: "today"
    val showBottomNavigation = topLevelDestinations.any { it.route == currentRoute }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = LifeSurface,
        bottomBar = {
            if (showBottomNavigation) {
                NavigationBar(
                    containerColor = LifeSurface,
                    tonalElevation = 0.dp
                ) {
                    topLevelDestinations.forEach { destination ->
                        val selected = currentRoute == destination.route
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(destination.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(destination.icon, contentDescription = destination.label)
                            },
                            label = { Text(destination.label) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = LifeBlue,
                                selectedTextColor = LifeBlue,
                                indicatorColor = LifeBlueSoft,
                                unselectedIconColor = LifeMuted,
                                unselectedTextColor = LifeMuted
                            )
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = "today",
            modifier = Modifier.fillMaxSize()
        ) {
            composable("today") {
                TodayScreen(
                    contentPadding = innerPadding,
                    onProfile = { navController.navigate("profile") },
                    onReview = { navController.navigate("review") }
                )
            }
            composable("tasks") {
                TasksRoute(
                    contentPadding = innerPadding,
                    onProfile = { navController.navigate("profile") },
                    onCloudConnection = { navController.navigate("cloud") },
                )
            }
            composable("projects") {
                ProjectsScreen(
                    contentPadding = innerPadding,
                    onProfile = { navController.navigate("profile") },
                    onCloudConnection = { navController.navigate("cloud") },
                )
            }
            composable("calendar") {
                CalendarScreen(
                    contentPadding = innerPadding,
                    onProfile = { navController.navigate("profile") }
                )
            }
            composable("collection") {
                CollectionScreen(
                    contentPadding = innerPadding,
                    onProfile = { navController.navigate("profile") }
                )
            }
            composable("profile") {
                ProfileScreen(
                    onBack = { navController.popBackStack() },
                    onCloud = { navController.navigate("cloud") },
                )
            }
            composable("cloud") {
                CloudConnectionScreen(onBack = { navController.popBackStack() })
            }
            composable("review") {
                ReviewScreen(onBack = { navController.popBackStack() })
            }
        }
    }
}
