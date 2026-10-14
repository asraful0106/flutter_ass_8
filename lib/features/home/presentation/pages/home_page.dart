import 'package:ass_8/features/home/presentation/widgets/interest_card.dart';
import 'package:ass_8/features/home/presentation/widgets/profile_part.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProfilePart(),

                // Interests header
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.5.h,
                          color: const Color.fromARGB(94, 167, 167, 167),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        child: Text(
                          "Interests",
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1.5.h,
                          color: const Color.fromARGB(94, 167, 167, 167),
                        ),
                      ),
                    ],
                  ),
                ),

                // Interest cards
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12.w,
                  children: [
                    Expanded(
                      child: InterestCard(
                        imageUrl:
                            "https://media.istockphoto.com/id/1442179368/photo/maldives-island.jpg?s=612x612&w=0&k=20&c=t38FJQ6YhyyZGN91A8tpn3nz9Aqcy_aXolImsOXOZ34=",
                        title: "Travel",
                        description: "Exploring new places around the world",
                        onViewMore: () {},
                      ),
                    ),
                    Expanded(
                      child: InterestCard(
                        imageUrl:
                            "https://media.istockphoto.com/id/1221568789/photo/videographer-with-professional-dslr-camera-in-hands.jpg?s=612x612&w=0&k=20&c=NRmXUNOdSLEIJ7afuehlrNOTJ1uFDQcU_XX7DwCXSkE=",
                        title: "Photography",
                        description: "Capturing moments and new perspectives",
                        onViewMore: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
