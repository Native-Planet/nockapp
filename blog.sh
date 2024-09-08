if [ "$1" = "new" ]; then
    cargo run --release --bin choo -- --new blog/hoon/lib/kernel.hoon blog/hoon
else
    cargo run --release --bin choo blog/hoon/lib/kernel.hoon blog/hoon
fi
mv out.jam blog/http.jam || { echo "build failed"; exit 1; }
cd blog
cargo run --release -- --new