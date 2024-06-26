//
//  GameplayView.swift
//  Nano2Challenge-2
//
//  Created by Bryan Vernanda on 18/05/24.
//

import SwiftUI

struct SingleplayerView: View {
    @State private var showBackground: Bool = true
    @State private var remainingTime: Int = 10
    @State private var difficultyLevel: Int = 1
    @State private var timeRemainingShowLevelUp = 6
    @State private var showCompleteKilling: Bool = false
    @State private var bounce: Bool = false
    @StateObject private var singleplayer: ViewController
    @State private var randomProTip: String
    @State private var completeKilling: Bool = false
    @State private var showLevelUp: Bool = false
    @State private var youDiedIndicator: Bool = false
    @State private var notNeedToShowAR: Bool = false
    @State private var winIndicator: Bool = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var levelText = ["Easy", "Medium", "Hard"]
    let deviceType = UIDevice.current.userInterfaceIdiom
    
    var proTips = [
        "If you keep losing, it might be time to take a break.",
        "Too many zombies? Just spam your attacks!",
        "As you advance to higher levels, zombies become more numerous and faster!",
        "Play with a friend for an easier chance to win.",
        "If you lose, the restart button is your best friend."
    ]
    
    init() {
        _randomProTip = State(initialValue: proTips.randomElement() ?? "If you keep losing, it might be time to take a break.")
        
        _singleplayer = StateObject(wrappedValue: ViewController(spawningZombiePage: .constant(2)))
    }
    
    var body: some View {
        ZStack {
            if !notNeedToShowAR {
                ARViewContainer(singleplayer: singleplayer)
                    .overlay(alignment: .bottom) {
                        Button {
                            ARManager.shared.actionStream.send(.attackButton)
                        } label: {
                            Image("AttackBowButton")
                                .resizable()
                                .scaledToFit()
                                .frame(width: UIScreen.main.bounds.width/8)
                        }
                        .position(x: UIScreen.main.bounds.width/1.12, y: deviceType == .pad ? UIScreen.main.bounds.height/1.18 :  UIScreen.main.bounds.height/1.3)
                        
                        Image(systemName: "plus")
                            .resizable()
                            .foregroundColor(Color.white)
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        
                        
                        
                        if (showCompleteKilling) && !(youDiedIndicator) {
                            if difficultyLevel == 3 {
                                ZStack { }
                                    .onAppear {
                                        winIndicator = true
                                    }
                            } else {
                                Image("LevelUpButton")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width/9)
                                    .position(CGPoint(x: deviceType == .pad ? UIScreen.main.bounds.width/1.09 : UIScreen.main.bounds.width/1.1, y: deviceType == .pad ? UIScreen.main.bounds.height/4.5 : UIScreen.main.bounds.height/3.1))
                                    .offset(y: bounce ? -10 : 10)
                                    .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: bounce)
                                    .onAppear {
                                        bounce = true
                                    }
                                    .onReceive(timer) {_ in
                                        if timeRemainingShowLevelUp > 0 {
                                            timeRemainingShowLevelUp -= 1
                                        } else {
                                            showLevelUp = true
                                        }
                                    }
                            }
                            
                            if showLevelUp {
                                Button {
                                    ARManager.shared.actionStreamContinue.send(.continueButton)
                                    
                                    showLevelUp = false
                                    showBackground = true
                                    remainingTime = 10
                                    timeRemainingShowLevelUp = 6
                                    showCompleteKilling = false
                                    completeKilling = false
                                    bounce = false
                                    difficultyLevel += 1
                                    
                                } label: {
                                    Image("NextLevelButton")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: UIScreen.main.bounds.width / 10)
                                }
                                .position(CGPoint(x: deviceType == .pad ? UIScreen.main.bounds.width/1.09 : UIScreen.main.bounds.width/1.1, y: deviceType == .pad ? UIScreen.main.bounds.height/13 : UIScreen.main.bounds.height/8.5))
                            }
                        } else if (completeKilling) && !(youDiedIndicator) {
                            ZStack{ }
                                .onAppear {
                                    startCountdownCompleteKilling(remainingTime: 8)
                                }
                        }
                        
                        DifficultyLevel(difficultyLevel: difficultyLevel, difficultyText: levelText[difficultyLevel - 1])
                            .position(CGPoint(x: deviceType == .pad ? UIScreen.main.bounds.width/6.5 : UIScreen.main.bounds.width/6, y: deviceType == .pad ? UIScreen.main.bounds.height/1.07 : UIScreen.main.bounds.height/1.1))
                        
                        if showBackground {
                            ZStack {
                                Color.white
                                    .ignoresSafeArea()
                                VStack {
                                    Spacer()
                                    HStack {
                                        Image(systemName: "exclamationmark.circle")
                                            .font(deviceType == .pad ? .title : .title2)
                                            .bold()
                                            .foregroundColor(.red)
                                        Text("Objective")
                                            .font(deviceType == .pad ? .title : .title2)
                                            .bold()
                                            .foregroundColor(.red)
                                    }
                                    .padding(.bottom, 2)
                                    Text("⚔️ Kill all the zombies to protect the Castle! ⚔️")
                                        .font(deviceType == .pad ? .title : .title2)
                                        .foregroundColor(.black)
                                        .padding(.bottom, 7)
                                    Text("Tip: \(randomProTip)")
                                        .font(deviceType == .pad ? .title3 : .subheadline)
                                        .foregroundColor(.black)
                                        .opacity(0.7)
                                    Spacer()
                                    VStack {
                                        HStack {
                                            Text("Game will start in..")
                                                .font(deviceType == .pad ? .title : .title2)
                                                .foregroundColor(.black)
                                            Text("\(remainingTime)")
                                                .font(deviceType == .pad ? .title : .title2)
                                                .bold()
                                                .foregroundColor(.black)
                                        }
                                        LoadingAnimation()
                                        .padding(.bottom, deviceType == .pad ? 50 : 25)
                                    }
                                    .padding(.bottom, 20)
                                }
                            }
                            .onAppear{
                                startCountdown()
                            }
                        }
                    }
            }
            
            if youDiedIndicator || winIndicator {
                EndGameView(winningCondition: $winIndicator, pageToGo: .constant(1), notNeedToShowAR: $notNeedToShowAR)
            }
            
        }
        .onReceive(singleplayer.$completeKillingZombies.receive(on: DispatchQueue.main)) { value in
            completeKilling = value
        }
        .onReceive(NotificationCenter.default.publisher(for: .castleDestroyed)) { _ in
            youDiedIndicator = true
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
    }
    
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                showBackground = false
                timer.invalidate()
            }
        }
    }
    
    private func startCountdownCompleteKilling(remainingTime: Int) {
        var remainingTime = remainingTime
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                showCompleteKilling = true
                timer.invalidate()
            }
        }
    }
}

#Preview {
    SingleplayerView()
}
