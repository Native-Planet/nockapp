<script>
  import { invoke } from "@tauri-apps/api/tauri";

  let selectedFile = null;
  let selectedImageUrl = "";
  let processedResult = null;

  async function processImage() {
    if (!selectedFile) return;

    const fileReader = new FileReader();
    fileReader.onload = async (e) => {
      const imageData = new Uint8Array(e.target.result);
      try {
        const result = await invoke("process_image", { imageData: Array.from(imageData) });
        processedResult = JSON.parse(result);
        console.log("Processed result:", processedResult);
      } catch (error) {
        console.error("Error processing image:", error);
        processedResult = { status: "error", message: error.toString() };
      }
    };
    fileReader.readAsArrayBuffer(selectedFile);
  }

  function handleFileSelect(event) {
    const file = event.target.files[0];
    if (file && file.type === "image/png") {
      // Always reset the state, even if it's the same file
      selectedFile = file;
      selectedImageUrl = URL.createObjectURL(file);
      processedResult = null;
      
      // Revoke the previous object URL to free up memory
      if (selectedImageUrl) {
        URL.revokeObjectURL(selectedImageUrl);
      }
      
      // Create a new object URL for the selected file
      selectedImageUrl = URL.createObjectURL(file);
      
      // Process the image
      processImage();
    } else {
      alert("Please select a PNG image.");
      event.target.value = "";
      selectedImageUrl = "";
    }
    
    // Reset the file input to allow selecting the same file again
    event.target.value = "";
  }


  /*
  const doFake = async () => {
    const result = await invoke("do_fake");
    console.log("Fake result:", JSON.parse(result));
  };
  */
</script>

<div class="container">
  {#if selectedImageUrl}
    <div class="image-container">
      <img src={selectedImageUrl} alt="Selected Image" />
    </div>
    {#if processedResult}
      <div class="result">
        <div class="result-text">
          {#if processedResult.status !== "passed"}
            <p class="error">Error: {processedResult.status}</p>
          {:else}
          {#each Object.entries(processedResult) as [key, value]}
            <p class="info">{key}: {value}</p>
          {/each}
          {/if}
        </div>
        <button class="half" on:click={() => document.getElementById('fileInput').click()}>Another PNG</button>
      </div>
    {:else}
      <div class="loading">Loading...</div>
    {/if}
  {:else}
    <button class="full" on:click={() => document.getElementById('fileInput').click()}>Select PNG</button>
  {/if}
  <input id="fileInput" type="file" accept=".png" on:change={handleFileSelect} style="display: none;" />

  <!-- <button on:click={doFake}>Do Fake</button> -->
</div>

<style>
  .container {
    width: 90vw;
    height: 90vh;
    text-align: center;
    margin: 5vh 5vw;
    display: flex;
    align-items: center;
    font-family: 'Courier New', Courier, monospace;
  }
  .full {
    margin: auto;
    width: 33%;
    padding: 2rem 0;
    background: #d9b99b;
    outline: none;
    border: none;
    border-radius: 1rem;
    font-size: 2rem;
    color: #faf0e6;
    box-shadow: 0 0 1rem 0 rgba(0, 0, 0, 0.2);
  }
  .loading {
    flex: 1;
    text-align: center;
    font-size: 2rem;
    overflow: hidden;
    color: #a17f5f;
    animation: blink 2s step-start infinite;
  }
  @keyframes blink {
    50% {
      opacity: 0.4;
    }
  }
  .result {
    flex: 1;
    display: flex;
    flex-direction: column;
    height: 100%;
  }
  .result-text {
    flex: 1;
    border: 4px solid #d9b99b;
    border-radius: 1rem;
    padding: 1rem;
    margin-left: 2rem;
    background: #faf0e6;
  }
  .half {
    padding: 2rem 0;
    margin: 2rem .3rem 0 3rem;
    background: #d9b99b;
    outline: none;
    border: none;
    border-radius: 1rem;
    font-size: 2rem;
    color: #faf0e6;
    box-shadow: 0 0 1rem 0 rgba(0, 0, 0, 0.2);
    font-family: inherit;
  }
  button:hover {
    background: #e4d5b7;
    cursor: pointer;
  }
  .image-container {
    flex: 1;
  }
  img {
    max-width: 100%;
    height: auto;
    object-fit: contain;
    border: 4px solid #d9b99b;
    overflow: hidden;
    border-radius: 1rem;
  }
  p {
    font-size: 1.2rem;
    font-weight: bold;
    line-height: 2rem;
    margin: 0;
    text-align: left;
    color: #a17f5f;

  }
  .error {
    color: lightcoral;
  }
</style>
