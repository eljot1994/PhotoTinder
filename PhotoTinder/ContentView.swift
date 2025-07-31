import SwiftUI
import Photos

struct ContentView: View {
    @StateObject var viewModel = PhotoTestViewModel()
    @State private var showMenu = false
    @State private var showingHistorySheet = false

    @AppStorage("appTheme") private var appTheme: AppTheme = .system


    var body: some View {
        ZStack {
            // Jednolity kolor tła, dostosowujący się do trybu jasnego/ciemnego
            Color.primary.opacity(0.05) // Bardzo jasne tło w trybie jasnym, subtelnie ciemne w trybie ciemnym
                .ignoresSafeArea()

            VStack {
                // Górny pasek z hamburgerem po prawej
                HStack {
                    VStack(alignment: .leading) {
                        if viewModel.totalPhotosCount > 0 && !viewModel.permissionDenied {
                            let currentPhotoNumber: Int
                            if viewModel.photos.isEmpty {
                                currentPhotoNumber = viewModel.totalPhotosCount
                            } else {
                                currentPhotoNumber = viewModel.totalPhotosCount - viewModel.photos.count + (viewModel.currentIndex + 1)
                            }

                            Text("Zdjęcie \(currentPhotoNumber) z \(viewModel.totalPhotosCount)")
                                .font(.headline)
                                .foregroundColor(.primary) // Dostosowuje się do motywu
                                .padding(.leading, 5) // Dodatkowy padding dla tekstu

                            ProgressView(value: viewModel.progressValue)
                                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor)) // Zmieniono na accentColor dla lepszej adaptacji
                                .frame(width: 150)
                                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                        }
                    }
                    .padding(.leading) // Padding dla VStack

                    Spacer()

                    Button(action: {
                        withAnimation { showMenu.toggle() }
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title)
                            .foregroundColor(.primary) // Dostosowuje się do motywu
                            .padding()
                    }
                }
                .padding(.top, 40)
                .background(Color.clear)

                Spacer()

                // Białe tło na zdjęcie + przycisk cofania w białym polu na dole
                ZStack(alignment: .bottom) {
                    Color(.systemBackground) // Dostosowuje się do trybu ciemnego/jasnego
                        .cornerRadius(30)
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)

                    VStack {
                        Spacer()

                        Group {
                            if viewModel.permissionDenied {
                                VStack(spacing: 20) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.orange)
                                    Text("Brak dostępu do zdjęć")
                                        .font(.title2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary) // Dostosowuje się do motywu
                                    Text("Aby korzystać z aplikacji, musisz zezwolić na dostęp do biblioteki zdjęć w ustawieniach systemowych.")
                                        .font(.callout)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.secondary) // Dostosowuje się do motywu
                                        .padding(.horizontal)
                                    Button("Otwórz Ustawienia") {
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                }
                                .padding()
                                .frame(maxWidth: 350, maxHeight: 600)
                            } else if let current = viewModel.currentPhoto() {
                                PhotoAssetView(asset: current.asset)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 350, maxHeight: 600)
                                    .clipShape(RoundedRectangle(cornerRadius: 25))
                                    .padding(.horizontal)
                                    .id(current.asset.localIdentifier)
                                    .scaleEffect(viewModel.offset == .zero ? 1 : 1.05) // Przywrócono skalę dla animacji swipe
                                    .offset(viewModel.offset)               // Przywrócono offset dla animacji swipe
                                    .rotationEffect(.degrees(Double(viewModel.offset.width / 20)))
                                    .gesture(
                                        DragGesture() // Przywrócono oryginalny DragGesture
                                            .onChanged { viewModel.offset = $0.translation }
                                            .onEnded { _ in viewModel.handleSwipeEnd() }
                                    )
                                    .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: viewModel.offset) // Istniejąca animacja swipe
                                    .overlay(swipeIconOverlay())
                                    .transition(.opacity)
                            } else {
                                Text("Brak zdjęć do przeglądnięcia")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .frame(maxHeight: 600)
                            }
                        }

                        Spacer()

                        // Przycisk cofania w białym polu na dole
                        Button(action: {
                            withAnimation { viewModel.undoLast() }
                        }) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .foregroundColor(viewModel.hasHistory ? .blue : .gray)
                        }
                        .disabled(!viewModel.hasHistory)
                        .padding(.bottom, 20)
                    }
                }
                .frame(maxWidth: 380, maxHeight: 700)
                .padding()

                Spacer()
            }

            // MENU wysuwane z góry z przyciskiem resetu
            if showMenu {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.resetProcessedPhotos()
                            withAnimation { showMenu = false }
                        }) {
                            Label("Resetuj", systemImage: "arrow.clockwise.circle.fill")
                                .font(.headline)
                                .foregroundColor(.red)
                                .padding(12)
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 50)

                    // Przycisk: Historia
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation { showMenu = false }
                            self.showingHistorySheet = true
                        }) {
                            Label("Historia", systemImage: "clock.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .padding(12)
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 10)

                    // Wybór motywu
                    HStack {
                        Spacer()
                        Picker("Motyw", selection: $appTheme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.rawValue)
                                    .tag(theme)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.trailing, 20)
                        .frame(width: 250)
                    }
                    .padding(.top, 10)

                    Spacer()
                }
                .background(
                    Color(.systemBackground).opacity(0.9) // Poprawka: Użyj adaptującego tła dla menu
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showMenu = false }
                        }
                )
                .transition(.move(edge: .top))
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showingHistorySheet) {
            HistoryView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    func swipeIconOverlay() -> some View {
        let offset = viewModel.offset
        Group {
            if offset.width < -50 {
                Image(systemName: "trash.fill")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    .clipShape(Circle())
                    .offset(x: -100)
            } else if offset.width > 50 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    .clipShape(Circle())
                    .offset(x: 100)
            } else if offset.height < -50 {
                Image(systemName: "heart.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    .clipShape(Circle())
                    .offset(y: -120)
            } else if offset.height > 50 {
                Image(systemName: "eye.slash.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    .clipShape(Circle())
                    .offset(y: 120)
            }
        }
    }
}
