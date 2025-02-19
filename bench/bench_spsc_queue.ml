open Lockfree

let item_count = 2_000_000

let rec try_until_success f =
  try f () with Spsc_queue.Full -> try_until_success f

let run () =
  let queue = Spsc_queue.create ~size_exponent:3 in
  let pusher =
    Domain.spawn (fun () ->
        let start_time = Unix.gettimeofday () in
        for i = 1 to item_count do
          try_until_success (fun () -> Spsc_queue.push queue i)
        done;
        start_time)
  in
  for _ = 1 to item_count do
    while Option.is_none (Spsc_queue.pop queue) do
      ()
    done
  done;
  let end_time = Unix.gettimeofday () in
  let start_time = Domain.join pusher in
  let time_diff = end_time -. start_time in
  time_diff

let create_output median_time median_throughput =
  let time =
    ({
       name = "time";
       value = `Numeric median_time;
       units = "s";
       description = "median time result";
     }
      : Benchmark_result.Metric.t)
  in
  let throughput =
    ({
       name = "throughput";
       value = `Numeric median_throughput;
       units = "item/s";
       description = "median throughput result";
     }
      : Benchmark_result.Metric.t)
  in
  let metrics = [time; throughput] in 
  ({name = "spsc-queue"; metrics} : Benchmark_result.t);;

let bench () =
  let results = ref [] in
  for i = 1 to 10 do
    let time = run () in
    if i > 1 then results := time :: !results
  done;
  let results = List.sort Float.compare !results in
  let median_time = List.nth results 4 in
  let throughput = Float.of_int item_count /. median_time in
  create_output median_time throughput;;
  
  